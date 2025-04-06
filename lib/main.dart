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

  DateTime parsePubDate(dynamic pubDateRaw) {
    if (pubDateRaw is! String || pubDateRaw.trim().isEmpty) {
      final now = DateTime.now().toUtc();
      print('Empty/invalid pubDate, using: $now');
      return now;
    }

    String pubDate = pubDateRaw.trim();
    print('Parsing pubDate: "$pubDate"');

    // Regex for RFC 822: "Sun, 06 Apr 2025 16:00:00 +0000" or "-0400"
    final rfc822Pattern = RegExp(
        r'^\w{3}, (\d{2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) ([+-]\d{4})$');
    if (rfc822Pattern.hasMatch(pubDate)) {
      final match = rfc822Pattern.firstMatch(pubDate)!;
      final day = int.parse(match.group(1)!);
      final monthStr = match.group(2)!;
      final year = int.parse(match.group(3)!);
      final hour = int.parse(match.group(4)!);
      final minute = int.parse(match.group(5)!);
      final second = int.parse(match.group(6)!);
      final offset = match.group(7)!;

      const months = {
        'Jan': 1,
        'Feb': 2,
        'Mar': 3,
        'Apr': 4,
        'May': 5,
        'Jun': 6,
        'Jul': 7,
        'Aug': 8,
        'Sep': 9,
        'Oct': 10,
        'Nov': 11,
        'Dec': 12
      };
      final month = months[monthStr]!;

      // Create local time first
      final localDate = DateTime(year, month, day, hour, minute, second);

      // Parse offset
      final offsetHours = int.parse(offset.substring(1, 3));
      final offsetMinutes = int.parse(offset.substring(3));
      final offsetDuration =
          Duration(hours: offsetHours, minutes: offsetMinutes);
      final offsetSign =
          offset.startsWith('+') ? -1 : 1; // + means ahead of UTC, so subtract

      // Adjust to UTC
      final utcDate = localDate
          .add(Duration(seconds: offsetSign * offsetDuration.inSeconds));
      print('Parsed RFC 822: $utcDate');
      return utcDate.toUtc();
    }

    // Regex for ISO 8601: "2025-04-06T16:00:00+00:00" or "2025-04-06 16:00:00Z"
    final iso8601Pattern = RegExp(
        r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})(Z|[+-]\d{2}:?\d{2})$');
    if (iso8601Pattern.hasMatch(pubDate)) {
      final match = iso8601Pattern.firstMatch(pubDate)!;
      final year = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);
      final hour = int.parse(match.group(4)!);
      final minute = int.parse(match.group(5)!);
      final second = int.parse(match.group(6)!);
      final offsetOrZ = match.group(7)!;

      // Create local time first
      final localDate = DateTime(year, month, day, hour, minute, second);

      if (offsetOrZ == 'Z') {
        print('Parsed ISO 8601 (Z): $localDate');
        return localDate.toUtc();
      } else {
        final offsetHours = int.parse(offsetOrZ.substring(1, 3));
        final offsetMinutes =
            offsetOrZ.length > 3 ? int.parse(offsetOrZ.substring(4)) : 0;
        final offsetDuration =
            Duration(hours: offsetHours, minutes: offsetMinutes);
        final offsetSign = offsetOrZ.startsWith('+')
            ? -1
            : 1; // + means ahead of UTC, so subtract

        // Adjust to UTC
        final utcDate = localDate
            .add(Duration(seconds: offsetSign * offsetDuration.inSeconds));
        print('Parsed ISO 8601: $utcDate');
        return utcDate.toUtc();
      }
    }

    // Fallback
    final now = DateTime.now().toUtc();
    print('No regex match, using: $now');
    return now;
  }

  String formatPubDateUTC(DateTime utcDateTime) {
    final df = DateFormat("EEE, MMM d, yyyy - HH:mm 'UTC'");
    return df.format(utcDateTime);
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
                    '${item.title?.toLowerCase().trim()}_${item.pubDate ?? ''}';
                if (!articleIdentifiers.contains(identifier)) {
                  articleIdentifiers.add(identifier);
                  final parsedDate =
                      parsePubDate(item.pubDate?.toString() ?? '');
                  final displayDateString = formatPubDateUTC(parsedDate);
                  final finalLink = getBestLink(item);
                  fetchedArticles.add({
                    'title': item.title ?? 'No title',
                    'link': finalLink,
                    'rawDate': parsedDate,
                    'pubDate': displayDateString,
                  });
                }
              }
            }
          } catch (e) {
            print('Error fetching feed $feedUrl: $e');
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

    setState(() {
      allArticles = fetchedArticles;
      filteredArticles = fetchedArticles;
      isLoading = false;
    });
  }

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
                  Text('Fetching feeds...'),
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
                  final bgColor = isEven ? Colors.orange : Colors.black;
                  final textColor = isEven ? Colors.black : Colors.white;
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
