import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:http/http.dart' as http;
import 'package:webfeed/webfeed.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';

void main() {
  tz.initializeTimeZones();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RSS Feeds',
      theme: ThemeData(
        primarySwatch: Colors.blue,
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
      "Bulletins":
          "https://feeds.marketwatch.com/marketwatch/bulletins", // HTTPS
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
  };

  List<Map<String, dynamic>> articles = [];
  bool isLoading = true;
  String loadingMessage = "Fetching feeds...";

  @override
  void initState() {
    super.initState();
    fetchFeeds();
  }

  Future<void> fetchFeeds() async {
    final userAgent =
        'Mozilla/5.0 (iPhone; CPU iPhone OS 10_3 like Mac OS X) AppleWebKit/602.1.50 (KHTML, like Gecko) Mobile/14E5239e';

    try {
      for (var feedCategory in rssFeeds.values) {
        for (var feedUrl in feedCategory.values) {
          try {
            final response = await http
                .get(Uri.parse(feedUrl), headers: {'User-Agent': userAgent});
            if (response.statusCode == 200) {
              final rssFeed = RssFeed.parse(response.body);

              List<Map<String, dynamic>> newArticles =
                  rssFeed.items!.map((item) {
                final pubDate = item.pubDate != null
                    ? (item.pubDate is DateTime
                        ? item.pubDate as DateTime
                        : DateTime.tryParse(item.pubDate.toString()) ??
                            DateTime.now())
                    : DateTime.now();
                final estDate = formatToEST(pubDate);

                return {
                  'title': item.title ?? 'No title',
                  'link': item.link ?? '',
                  'pubDate': estDate.toString(),
                };
              }).toList();

              setState(() {
                articles.addAll(newArticles);
                articles.sort((a, b) =>
                    b['pubDate'].compareTo(a['pubDate'])); // Sort by date
              });
            }
          } catch (e) {
            debugPrint("Error fetching/parsing feed: $feedUrl. Error: $e");
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching feeds: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  DateTime formatToEST(DateTime dateTime) {
    final est = tz.getLocation('America/New_York');
    return tz.TZDateTime.from(dateTime, est);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Investment News Feeds'),
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(loadingMessage),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: fetchFeeds,
              child: ListView.builder(
                itemCount: articles.length,
                itemBuilder: (context, index) {
                  final article = articles[index];
                  return ListTile(
                    title: Text(article['title']!),
                    subtitle: Text(article['pubDate']),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              WebViewScreen(url: article['link']!),
                        ),
                      );
                    },
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
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Article'),
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}
