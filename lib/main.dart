import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const WeatherHomePage(),
    );
  }
}

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key});

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  final TextEditingController _searchController = TextEditingController();
  
  String cityName = 'Kampala';
  String temperature = '--';
  String weatherCondition = '--';
  String humidity = '--';
  String windSpeed = '--';
  String airQuality = '--';
  bool isLoading = false;
  String errorMessage = '';
  double lat = 0.0;
  double lon = 0.0;
  List<Map<String, dynamic>> forecastList = [];

  final String apiKey = 'cfd1cd59637b570ac3140015ab281f7b';

  Future<void> fetchWeather(String city) async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final weatherUrl = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&units=metric'
      );

      final weatherResponse = await http.get(weatherUrl);

      if (weatherResponse.statusCode == 200) {
        final weatherData = json.decode(weatherResponse.body);

    setState(() {
        cityName = weatherData['name'];
        temperature = weatherData['main']['temp'].toStringAsFixed(1);
        weatherCondition = weatherData['weather'][0]['description'];
        humidity = weatherData['main']['humidity'].toString();
        windSpeed = weatherData['wind']['speed'].toString();
        lat = weatherData['coord']['lat'];
        lon = weatherData['coord']['lon'];
        isLoading = false;
      });
      await fetchAirQuality(lat, lon);
      await fetchForecast(city);
      } else {
        setState(() {
          errorMessage = 'City not found. Please try again.';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'No internet connection.';
        isLoading = false;
      });
    }
  }
  Future<void> fetchAirQuality(double lat, double lon) async {
    try {
      final airUrl = Uri.parse(
        'https://api.openweathermap.org/data/2.5/air_pollution?lat=$lat&lon=$lon&appid=$apiKey'
      );

      final airResponse = await http.get(airUrl);

      if (airResponse.statusCode == 200) {
        final airData = json.decode(airResponse.body);
        int aqi = airData['list'][0]['main']['aqi'];

        String airQualityText = '';
        switch (aqi) {
          case 1:
            airQualityText = 'Good';
            break;
          case 2:
            airQualityText = 'Fair';
            break;
          case 3:
            airQualityText = 'Moderate';
            break;
          case 4:
            airQualityText = 'Poor';
            break;
          case 5:
            airQualityText = 'Very Poor';
            break;
          default:
            airQualityText = 'Unknown';
        }

        setState(() {
          airQuality = airQualityText;
        });
      }
    } catch (e) {
      setState(() {
        airQuality = 'N/A';
      });
    }
  }
  Future<void> fetchForecast(String city) async {
    try {
      final forecastUrl = Uri.parse(
        'https://api.openweathermap.org/data/2.5/forecast?q=$city&appid=$apiKey&units=metric'
      );

      final forecastResponse = await http.get(forecastUrl);

      if (forecastResponse.statusCode == 200) {
        final forecastData = json.decode(forecastResponse.body);
        List<Map<String, dynamic>> dailyForecasts = [];
        Set<String> addedDates = {};

        for (var item in forecastData['list']) {
          String date = item['dt_txt'].toString().split(' ')[0];
          if (!addedDates.contains(date) && dailyForecasts.length < 5) {
            addedDates.add(date);
            dailyForecasts.add({
              'date': date,
              'temp': item['main']['temp'].toStringAsFixed(1),
              'condition': item['weather'][0]['description'],
            });
          }
        }

        setState(() {
          forecastList = dailyForecasts;
        });
      }
    } catch (e) {
      print('Forecast error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    fetchWeather(cityName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade900,
      appBar: AppBar(
        backgroundColor: Colors.blue.shade900,
        title: const Text(
          'Weather App',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search for a city...',
                  hintStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: Colors.blue.shade700,
                  prefixIcon: const Icon(Icons.search, color: Colors.white),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    fetchWeather(value);
                  }
                },
              ),
              const SizedBox(height: 20),
              if (errorMessage.isNotEmpty)
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              const SizedBox(height: 20),
              if (isLoading)
                const CircularProgressIndicator(color: Colors.white)
              else
                Column(
                  children: [
                    const Icon(
                      Icons.wb_sunny,
                      color: Colors.yellow,
                      size: 100,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '$temperature°C',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 72,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      weatherCondition,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      cityName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade700,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Icon(Icons.water_drop, color: Colors.white),
                              const SizedBox(height: 8),
                              const Text('Humidity',
                                  style: TextStyle(color: Colors.white60)),
                              Text('$humidity%',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Column(
                            children: [
                              const Icon(Icons.wind_power, color: Colors.white),
                              const SizedBox(height: 8),
                              const Text('Wind',
                                  style: TextStyle(color: Colors.white60)),
                              Text('$windSpeed km/h',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Column(
                            children: [
                              const Icon(Icons.air, color: Colors.white),
                              const SizedBox(height: 8),
                              const Text('Air Quality',
                                  style: TextStyle(color: Colors.white60)),
                              Text(airQuality,
                                  style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade700,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '5-Day Forecast',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...forecastList.map((forecast) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    forecast['date'],
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 14),
                                  ),
                                  Text(
                                    forecast['condition'],
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 14),
                                  ),
                                  Text(
                                    '${forecast['temp']}°C',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}