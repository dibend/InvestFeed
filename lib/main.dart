import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webfeed/webfeed.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InvestFeed',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.deepOrange,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: Colors.deepOrange,
          secondary: Colors.orange,
        ),
      ),
      home: const FeedListPage(),
    );
  }
}

class FeedListPage extends StatefulWidget {
  const FeedListPage({super.key});

  @override
  FeedListPageState createState() => FeedListPageState();
}

class FeedListPageState extends State<FeedListPage> {
  final Map<String, Map<String, String>> rssFeeds = {
    "MarketWatch": {
      "Top Stories":
          "https://feeds.content.dowjones.io/public/rss/mw_topstories",
      "Real-Time Headlines":
          "https://feeds.content.dowjones.io/public/rss/mw_realtimeheadlines",
      "Bulletins": "https://feeds.marketwatch.com/marketwatch/bulletins",
      "Market Pulse":
          "https://feeds.content.dowjones.io/public/rss/mw_marketpulse",
    },
    "Nasdaq": {
      "Original": "https://www.nasdaq.com/feed/nasdaq-original/rss.xml",
      "Cryptocurrencies":
          "https://www.nasdaq.com/feed/rssoutbound?category=Cryptocurrencies",
      "Markets": "https://www.nasdaq.com/feed/rssoutbound?category=Markets",
    },
    "CNBC": {
      "Top News": "https://www.cnbc.com/id/100003114/device/rss",
      "Investing": "https://www.cnbc.com/id/15839069/device/rss",
      "Finance": "https://www.cnbc.com/id/15839263/device/rss",
    },
    "Bloomberg": {
      "Markets": "https://feeds.bloomberg.com/markets/news.rss",
      "Crypto": "https://feeds.bloomberg.com/crypto/news.rss",
      "Technology": "https://feeds.bloomberg.com/technology/news.rss",
    },
    "Yahoo Finance": {
      "Top News": "https://finance.yahoo.com/news/rss",
      "Market News": "https://finance.yahoo.com/markets/rss",
    },
    "Fidelity": {
      "Viewpoints": "https://www.fidelity.com/viewpoints.xml",
    },
    "Morgan Stanley": {
      "Insights": "https://www.morganstanley.com/feeds/rss/news.xml",
    },
    "Goldman Sachs": {
      "Insights": "https://www.goldmansachs.com/insights/rss/",
    },
    "Ritholtz/Compound": {
      "Josh Brown (TRB)": "https://thereformedbroker.com/feed/",
      "RWM Blog": "https://ritholtz.com/feed/",
    },
    "CoinDesk": {
      "Latest News": "https://www.coindesk.com/arc/outboundfeeds/rss/",
      "Markets":
          "https://www.coindesk.com/arc/outboundfeeds/rss/?outputType=xml&tag=markets",
    },
    "CoinTelegraph": {
      "Latest News": "https://cointelegraph.com/rss",
      "Blockchain": "https://cointelegraph.com/tags/blockchain/rss",
    },
    "The Block": {
      "News": "https://www.theblock.co/feed/rss",
    },
    "Decrypt": {
      "News": "https://decrypt.co/feed",
    },
    "Bankless": {
      "Articles": "https://www.bankless.com/feed",
    },
    "Messari": {
      "Research": "https://messari.io/feed",
    },
    "Reuters": {
      "Markets":
          "https://www.reuters.com/arc/outboundfeeds/rss/?outputType=xml&category=markets",
      "Business":
          "https://www.reuters.com/arc/outboundfeeds/rss/?outputType=xml&category=business",
    },
    "Financial Times": {
      "Markets": "https://www.ft.com/markets?format=rss",
      "Companies": "https://www.ft.com/companies?format=rss",
    },
    "The Economist": {
      "Finance & Economics":
          "https://www.economist.com/finance-and-economics/rss.xml",
    },
  };

  List<Map<String, dynamic>> allArticles = [];
  List<Map<String, dynamic>> filteredArticles = [];

  bool isLoading = true;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchFeeds();
  }

  String formatPubDateUTC(DateTime utcDateTime) {
    final df = DateFormat("EEE, MMM d, yyyy - HH:mm 'UTC'");
    return df.format(utcDateTime.toUtc());
  }

  String getBestLink(RssItem item) {
    final link = item.link?.trim() ?? '';
    if (link.isNotEmpty) return link;
    if (item.enclosure?.url != null && item.enclosure!.url!.isNotEmpty) {
      return item.enclosure!.url!.trim();
    }
    if (item.guid != null && item.guid!.isNotEmpty) return item.guid!.trim();
    return '';
  }

  Future<void> fetchFeeds() async {
    final userAgent =
        'Mozilla/5.0 (iPhone; CPU iPhone OS 10_3 like Mac OS X) AppleWebKit/602.1.50 (KHTML, like Gecko) Mobile/14E5239e';

    final Set<String> articleIdentifiers = {};
    final List<Map<String, dynamic>> fetchedArticles = [];
    // Establish a consistent "now" for this entire fetch operation
    final DateTime currentFetchTimeUtc = DateTime.now().toUtc();

    final List<Future<void>> publisherFutures = [];
    rssFeeds.forEach((publisher, feedMap) {
      publisherFutures.add(() async {
        for (var feedUrl in feedMap.values) {
          try {
            final response = await http
                .get(Uri.parse(feedUrl), headers: {'User-Agent': userAgent});
            if (response.statusCode == 200) {
              final rssFeed = RssFeed.parse(response.body);
              for (var item in rssFeed.items ?? []) {
                final identifier =
                    '${item.title?.toLowerCase().trim()}_${item.pubDate?.toIso8601String() ?? getBestLink(item)}'; // Made identifier slightly more robust

                if (!articleIdentifiers.contains(identifier)) {
                  articleIdentifiers.add(identifier);

                  DateTime rawDateUtc;
                  if (item.pubDate != null) {
                    DateTime parsedDate = item.pubDate!.toUtc();

                    // **Intelligent Validation: Check for future dates**
                    if (parsedDate.isAfter(currentFetchTimeUtc)) {
                      print(
                          'Warning: Article "${item.title}" from $publisher has a future pubDate ($parsedDate). Capping to current fetch time ($currentFetchTimeUtc).');
                      rawDateUtc = currentFetchTimeUtc;
                    } else {
                      rawDateUtc = parsedDate;
                    }
                  } else {
                    // Fallback if webfeed couldn't parse pubDate or it's missing.
                    print(
                        'Info: item.pubDate is null for article "${item.title}" from $publisher. Defaulting to current fetch time ($currentFetchTimeUtc).');
                    rawDateUtc = currentFetchTimeUtc;
                  }

                  final displayDateString = formatPubDateUTC(rawDateUtc);
                  final finalLink = getBestLink(item);

                  fetchedArticles.add({
                    'title': item.title ?? 'No title',
                    'link': finalLink,
                    'rawDate': rawDateUtc,
                    'pubDate': displayDateString,
                    'source': publisher // Optional: to help trace issues
                  });
                }
              }
            } else {
              print(
                  'Failed to fetch feed $feedUrl (Publisher: $publisher): HTTP ${response.statusCode}');
            }
          } catch (e) {
            print(
                'Error fetching/parsing feed $feedUrl (Publisher: $publisher): $e');
          }
        }
      }());
    });
    await Future.wait(publisherFutures);

    fetchedArticles.sort((a, b) {
      final dateA = a['rawDate'] as DateTime;
      final dateB = b['rawDate'] as DateTime;
      return dateB.compareTo(dateA);
    });

    if (mounted) {
      setState(() {
        allArticles = fetchedArticles;
        filteredArticles = fetchedArticles;
        isLoading = false;
      });
    }
  }

  void filterSearchResults(String query) {
    setState(() {
      final lowerQuery = query.toLowerCase();
      filteredArticles = allArticles.where((article) {
        final title = article['title'].toString().toLowerCase();
        // final source = article['source'].toString().toLowerCase(); // Optionally search by source
        return title.contains(lowerQuery); // || source.contains(lowerQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('InvestFeed'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              width: 200,
              child: TextField(
                controller: searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.black45,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: filterSearchResults,
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Fetching feeds... This may take a moment.'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: fetchFeeds,
              child: ListView.builder(
                itemCount: filteredArticles.length,
                itemBuilder: (context, index) {
                  final article = filteredArticles[index];
                  final isEven = index % 2 == 0;
                  final bgColor =
                      isEven ? Colors.orange[700] : Colors.grey[900];
                  final textColor = isEven ? Colors.white : Colors.orangeAccent;

                  return Container(
                    color: bgColor,
                    child: ListTile(
                      title: Text(
                        article['title'],
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        "${article['pubDate']} - ${article['source'] ?? 'Unknown Source'}", // Display source
                        style: TextStyle(color: textColor?.withOpacity(0.8)),
                      ),
                      onTap: () {
                        final link = article['link'];
                        if (link != null && link.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WebViewScreen(url: link),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'No link available for this article.')),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  final String url;
  const WebViewScreen({Key? key, required this.url}) : super(key: key);

  @override
  _WebViewScreenState createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36")
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (String url) {
          print('Page started loading: $url');
        },
        onPageFinished: (String url) {
          print('Page finished loading: $url');
        },
        onWebResourceError: (WebResourceError error) {
          print('''
Page resource error:
  code: ${error.errorCode}
  description: ${error.description}
  errorType: ${error.errorType}
  isForMainFrame: ${error.isForMainFrame}
          ''');
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Article'),
        backgroundColor: Colors.deepOrange,
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}
