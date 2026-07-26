import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'login_page.dart';
import 'splash_screen.dart';

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C3FC5),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
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
  String iconCode = '01d';
  bool isLoading = false;
  bool isLocating = false;
  String errorMessage = '';
  String weatherAlert = '';
  double lat = 0.0;
  double lon = 0.0;
  List<Map<String, dynamic>> forecastList = [];

  DateTime? lastUpdated;

  final String apiKey = 'cfd1cd59637b570ac3140015ab281f7b';

  // ---- Theme colors (dark navy -> purple, like the reference) ----
  static const Color bgTop = Color(0xFF141E46);
  static const Color bgBottom = Color(0xFF6A3FA0);
  static const Color cardColor = Color(0x33FFFFFF); // translucent glass
  static const Color cardBorder = Color(0x22FFFFFF);
  static const Color accentYellow = Color(0xFFFFC940);
  static const Color accentPink = Color(0xFFB84C8C);

  Future<void> fetchWeather(String city) async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final weatherUrl = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&units=metric',
      );

      final weatherResponse = await http.get(weatherUrl);

      if (weatherResponse.statusCode == 200) {
        final weatherData = json.decode(weatherResponse.body);
        _applyWeatherData(weatherData);
        await fetchAirQuality(lat, lon);
        await fetchForecast(city);
      } else {
        setState(() {
          errorMessage = 'City not found. Please try again.';
          isLoading = false;
        });
      }
    } on SocketException {
      setState(() {
        errorMessage = 'No internet connection.';
        isLoading = false;
      });
    } catch (e) {
      debugPrint('fetchWeather error: $e');
      setState(() {
        errorMessage = 'Something went wrong. Please try again.';
        isLoading = false;
      });
    }
  }

  // ---------------------------------------------------------------------
  // GPS: only runs when the user taps the location button — never
  // automatically on launch. Falls back to whatever city is currently
  // shown if location can't be obtained, instead of breaking the screen.
  // ---------------------------------------------------------------------
  Future<void> fetchWeatherByLocation() async {
    setState(() {
      isLocating = true;
      errorMessage = '';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          errorMessage = 'Location services are off. Enable GPS and try again.';
          isLocating = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            errorMessage = 'Location permission denied.';
            isLocating = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          errorMessage =
              'Location permission permanently denied. Enable it in device settings.';
          isLocating = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      final weatherUrl = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather'
        '?lat=${position.latitude}&lon=${position.longitude}'
        '&appid=$apiKey&units=metric',
      );

      final weatherResponse = await http.get(weatherUrl);

      if (weatherResponse.statusCode == 200) {
        final weatherData = json.decode(weatherResponse.body);
        _applyWeatherData(weatherData);
        await fetchAirQuality(lat, lon);
        await fetchForecast(cityName);
      } else {
        setState(() {
          errorMessage = 'Could not load weather for your location.';
        });
      }
    } on SocketException {
      setState(() {
        errorMessage = 'No internet connection.';
      });
    } catch (e) {
      debugPrint('fetchWeatherByLocation error: $e');
      setState(() {
        errorMessage = 'Could not get your location. Try searching a city instead.';
      });
    } finally {
      setState(() {
        isLocating = false;
        isLoading = false;
      });
    }
  }

  void _applyWeatherData(Map<String, dynamic> weatherData) {
    double temp = (weatherData['main']['temp'] as num).toDouble();
    double wind = (weatherData['wind']['speed'] as num).toDouble();
    int humid = weatherData['main']['humidity'] as int;
    String condition =
        (weatherData['weather'][0]['description'] as String).toLowerCase();
    String icon = weatherData['weather'][0]['icon'] as String;

    String alert = '';
    if (temp >= 35) {
      alert = '🔥 Heat Alert! Temperature is very high. Stay hydrated!';
    } else if (temp <= 10) {
      alert = '🥶 Cold Alert! Temperature is very low. Dress warmly!';
    } else if (wind >= 20) {
      alert = '💨 Strong Wind Alert! Be careful outdoors!';
    } else if (humid >= 90) {
      alert = '💧 High Humidity Alert! It feels very humid today!';
    } else if (condition.contains('storm') ||
        condition.contains('thunder') ||
        condition.contains('heavy rain')) {
      alert = '⛈️ Severe Weather Alert! Stay indoors if possible!';
    }

    setState(() {
      cityName = weatherData['name'];
      temperature = temp.toStringAsFixed(1);
      weatherCondition = condition;
      humidity = humid.toString();
      windSpeed = wind.toString();
      iconCode = icon;
      lat = (weatherData['coord']['lat'] as num).toDouble();
      lon = (weatherData['coord']['lon'] as num).toDouble();
      weatherAlert = alert;
      isLoading = false;

      final int dtUtcSeconds = weatherData['dt'] as int;
      final int timezoneOffsetSeconds = weatherData['timezone'] as int;
      lastUpdated = DateTime.utc(1970, 1, 1).add(
        Duration(seconds: dtUtcSeconds + timezoneOffsetSeconds),
      );
    });
  }

  Future<void> fetchAirQuality(double lat, double lon) async {
    try {
      final airUrl = Uri.parse(
        'https://api.openweathermap.org/data/2.5/air_pollution?lat=$lat&lon=$lon&appid=$apiKey',
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
      debugPrint('fetchAirQuality error: $e');
      setState(() {
        airQuality = 'N/A';
      });
    }
  }

  Future<void> fetchForecast(String city) async {
    try {
      final forecastUrl = Uri.parse(
        'https://api.openweathermap.org/data/2.5/forecast?q=$city&appid=$apiKey&units=metric',
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
              'icon': item['weather'][0]['icon'],
            });
          }
        }

        setState(() {
          forecastList = dailyForecasts;
        });
      }
    } catch (e) {
      debugPrint('Forecast error: $e');
    }
  }

  String _formatTime(DateTime dt) {
    int hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    String minute = dt.minute.toString().padLeft(2, '0');
    String period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  // Short weekday label e.g. "Mon" from a "YYYY-MM-DD" string.
  String _weekdayShort(String isoDate) {
    final date = DateTime.parse(isoDate);
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[date.weekday - 1];
  }

  String _iconUrl(String code) => 'https://openweathermap.org/img/wn/$code@2x.png';

  @override
  void initState() {
    super.initState();
    fetchWeather(cityName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgTop, bgBottom],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => fetchWeather(cityName),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---- Top bar ----
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Weather App',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white70),
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const LoginPage()),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ---- Search bar + GPS button ----
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: cardBorder),
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Search for a city...',
                              hintStyle: TextStyle(color: Colors.white60),
                              prefixIcon:
                                  Icon(Icons.search, color: Colors.white70),
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 14),
                            ),
                            style: const TextStyle(color: Colors.white),
                            onSubmitted: (value) {
                              if (value.isNotEmpty) {
                                fetchWeather(value);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF3F6FD1),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: isLocating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.my_location,
                                  color: Colors.white),
                          onPressed:
                              isLocating ? null : fetchWeatherByLocation,
                          tooltip: 'Use my location',
                        ),
                      ),
                    ],
                  ),

                  if (errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage,
                      style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 14),
                    ),
                  ],

                  if (weatherAlert.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _GlassCard(
                      color: const Color(0x55FF8A00),
                      child: Text(
                        weatherAlert,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    )
                  else ...[
                    // ---- Main weather hero ----
                    Center(
                      child: Column(
                        children: [
                          Image.network(
                            _iconUrl(iconCode),
                            width: 120,
                            height: 120,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.wb_sunny,
                                    color: accentYellow, size: 100),
                          ),
                          Text(
                            '$temperature°',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            weatherCondition,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            cityName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (lastUpdated != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Local time: ${_formatTime(lastUpdated!)}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ---- Stats row (glass card) ----
                    _GlassCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatItem(
                            icon: Icons.water_drop,
                            label: 'Humidity',
                            value: '$humidity%',
                          ),
                          _StatItem(
                            icon: Icons.air,
                            label: 'Wind',
                            value: '$windSpeed km/h',
                          ),
                          _StatItem(
                            icon: Icons.eco,
                            label: 'Air Quality',
                            value: airQuality,
                            valueColor: const Color(0xFF7CE0A6),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ---- 5-Day forecast strip ----
                    const Text(
                      '5-Day Forecast',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 130,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: forecastList.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final f = forecastList[index];
                          return _ForecastChip(
                            day: _weekdayShort(f['date']),
                            iconUrl: _iconUrl(f['icon']),
                            temp: '${f['temp']}°C',
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Reusable glass-style card used across the redesigned UI.
// ---------------------------------------------------------------------
class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color? color;

  const _GlassCard({required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? _WeatherHomePageState.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _WeatherHomePageState.cardBorder),
      ),
      child: child,
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 22),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _ForecastChip extends StatelessWidget {
  final String day;
  final String iconUrl;
  final String temp;

  const _ForecastChip({
    required this.day,
    required this.iconUrl,
    required this.temp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7A3FA0), Color(0xFFB84C8C)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(day,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          Image.network(
            iconUrl,
            width: 40,
            height: 40,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.cloud, color: Colors.white, size: 32),
          ),
          Text(temp,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}