import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:http/http.dart' as http;
import 'package:webfeed/webfeed.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';

/// Entry point
void main() {
  tz.initializeTimeZones();
  runApp(const MyApp());
}

/// Main app uses a dark theme with orange highlights.
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
  /// Combined RSS Feeds including The Compound, Ritholtz, Creative Planning, etc.
  final Map<String, Map<String, String>> rssFeeds = {
    "MarketWatch": {
      "Top Stories":
          "https://feeds.content.dowjones.io/public/rss/mw_topstories",
      "Real-Time Headlines":
          "https://feeds.content.dowjones.io/public/rss/mw_realtimeheadlines",
      "Bulletins": "https://feeds.marketwatch.com/marketwatch/bulletins",
      "Market Pulse":
          "https://feeds.content.dowjones.io/public/rss/mw_marketpulse",
      "Investing": "https://feeds.marketwatch.com/marketwatch/investing",
      "Mutual Funds": "https://feeds.marketwatch.com/marketwatch/mutualfunds",
      "ETFs": "https://feeds.marketwatch.com/marketwatch/etfs",
      "Retirement": "https://feeds.marketwatch.com/marketwatch/retirement",
    },
    "Nasdaq": {
      "Original": "https://www.nasdaq.com/feed/nasdaq-original/rss.xml",
      "Commodities":
          "https://www.nasdaq.com/feed/rssoutbound?category=Commodities",
      "Cryptocurrencies":
          "https://www.nasdaq.com/feed/rssoutbound?category=Cryptocurrencies",
      "Dividends": "https://www.nasdaq.com/feed/rssoutbound?category=Dividends",
      "Earnings": "https://www.nasdaq.com/feed/rssoutbound?category=Earnings",
      "ETFs": "https://www.nasdaq.com/feed/rssoutbound?category=ETFs",
      "IPOs": "https://www.nasdaq.com/feed/rssoutbound?category=IPOs",
      "Markets": "https://www.nasdaq.com/feed/rssoutbound?category=Markets",
      "Options": "https://www.nasdaq.com/feed/rssoutbound?category=Options",
      "Stocks": "https://www.nasdaq.com/feed/rssoutbound?category=Stocks",
    },
    "CNBC": {
      "Top News": "https://www.cnbc.com/id/100003114/device/rss",
      "World News": "https://www.cnbc.com/id/100727362/device/rss",
      "Business News": "https://www.cnbc.com/id/10001147/device/rss",
      "Earnings": "https://www.cnbc.com/id/15839135/device/rss",
      "Investing": "https://www.cnbc.com/id/15839069/device/rss",
      "Economy": "https://www.cnbc.com/id/20910258/device/rss",
      "Finance": "https://www.cnbc.com/id/15839263/device/rss",
      "Health Care": "https://www.cnbc.com/id/10000108/device/rss",
      "Real Estate": "https://www.cnbc.com/id/10000115/device/rss",
      "Technology": "https://www.cnbc.com/id/10001045/device/rss",
      "Small Business": "https://www.cnbc.com/id/10000113/device/rss",
      "Personal Finance": "https://www.cnbc.com/id/10000520/device/rss",
      "Breaking News": "https://www.cnbc.com/id/15839135/device/rss",
      "Stock Market Data": "https://www.cnbc.com/id/15839069/device/rss",
    },
    "Bloomberg": {
      "Markets": "https://feeds.bloomberg.com/markets/news.rss",
      "Politics": "https://feeds.bloomberg.com/politics/news.rss",
      "Technology": "https://feeds.bloomberg.com/technology/news.rss",
      "Wealth": "https://feeds.bloomberg.com/wealth/news.rss",
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
    // The Compound / Ritholtz Wealth
    "Ritholtz/Compound": {
      "Josh Brown (TRB)": "https://thereformedbroker.com/feed/",
      "Michael Batnick": "https://theirrelevantinvestor.com/feed/",
      "Ben Carlson": "https://awealthofcommonsense.com/feed/",
      "RWM Blog": "https://ritholtzwealth.com/blog/feed/",
      "Animal Spirits Podcast": "https://animalspiritspod.libsyn.com/rss",
    },
    // Creative Planning
    "Creative Planning": {
      "Main Feed": "https://creativeplanning.com/feed",
    },
  };

  /// We'll store both the date object and the display date in each article, so we can sort by the date object.
  List<Map<String, dynamic>> allArticles = [];
  List<Map<String, dynamic>> filteredArticles = [];

  bool isLoading = true;
  String loadingMessage = "Fetching feeds...";

  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchFeeds();
  }

  /// Safely parse RSS pubDate field into a DateTime
  DateTime parsePubDate(dynamic pubDateRaw) {
    try {
      if (pubDateRaw is DateTime) {
        return pubDateRaw;
      } else if (pubDateRaw is String) {
        return DateTime.tryParse(pubDateRaw) ?? DateTime.now();
      }
    } catch (_) {}
    return DateTime.now();
  }

  /// Convert given DateTime to EST and then format it with intl's DateFormat
  String formatPubDateEST(DateTime dateTime) {
    final est = tz.getLocation('America/New_York');
    final estDateTime = tz.TZDateTime.from(dateTime, est);
    final df = DateFormat("EEE, MMM d, yyyy - h:mm a 'ET'");
    return df.format(estDateTime);
  }

  Future<void> fetchFeeds() async {
    final userAgent =
        'Mozilla/5.0 (iPhone; CPU iPhone OS 10_3 like Mac OS X) AppleWebKit/602.1.50 (KHTML, like Gecko) Mobile/14E5239e';
    final Set<String> articleIdentifiers = {};

    final List<Map<String, dynamic>> fetchedArticles = [];

    try {
      for (var feedCategory in rssFeeds.values) {
        for (var feedUrl in feedCategory.values) {
          try {
            final response = await http
                .get(Uri.parse(feedUrl), headers: {'User-Agent': userAgent});
            if (response.statusCode == 200) {
              final rssFeed = RssFeed.parse(response.body);
              for (var item in rssFeed.items ?? []) {
                final identifier =
                    '${item.title?.toLowerCase().trim()}_${item.pubDate ?? ''}';
                if (!articleIdentifiers.contains(identifier)) {
                  articleIdentifiers.add(identifier);

                  final parsedDate = parsePubDate(item.pubDate);
                  final displayDateString = formatPubDateEST(parsedDate);

                  fetchedArticles.add({
                    'title': item.title ?? 'No title',
                    'link': item.link ?? '',
                    'rawDate': parsedDate, // store for sorting
                    'pubDate': displayDateString, // store for display
                  });
                }
              }
            } else {
              // Non-200 response, skip
            }
          } catch (e) {
            // Parsing or fetch error, skip
          }
        }
      }
    } catch (e) {
      // Global fetch error, skip
    }

    // Now sort final list by descending rawDate
    fetchedArticles.sort((a, b) {
      final dateA = a['rawDate'] as DateTime;
      final dateB = b['rawDate'] as DateTime;
      return dateB.compareTo(dateA);
    });

    setState(() {
      allArticles = fetchedArticles;
      filteredArticles = fetchedArticles;
      isLoading = false;
    });
  }

  /// Filter method for search bar
  void filterSearchResults(String query) {
    setState(() {
      final lowerQuery = query.toLowerCase();
      filteredArticles = allArticles.where((article) {
        final title = article['title'].toString().toLowerCase();
        return title.contains(lowerQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('InvestFeed'),
        actions: [
          // Add search bar on top
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
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(loadingMessage,
                      style: const TextStyle(color: Colors.white)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: fetchFeeds,
              child: ListView.builder(
                itemCount: filteredArticles.length,
                itemBuilder: (context, index) {
                  final article = filteredArticles[index];
                  // We'll alternate row colors for a subtle style.
                  // Now we want even index => orange bg, black text
                  // odd index => black bg, white text
                  final isEven = index % 2 == 0;
                  final bgColor = isEven ? Colors.orange : Colors.black;
                  final textColor = isEven ? Colors.black : Colors.white;

                  return Container(
                    color: bgColor,
                    child: ListTile(
                      title: Text(
                        article['title'],
                        style: TextStyle(
                            color: textColor, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        article['pubDate'],
                        style: TextStyle(color: textColor),
                      ),
                      onTap: () {
                        final link = article['link'];
                        if (link.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WebViewScreen(url: link),
                            ),
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

/// A simple in-app WebView screen.
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
