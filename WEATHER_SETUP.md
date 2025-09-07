# 🌤️ Weather API Setup Guide

## Getting Real Weather Data

The app now supports real weather data from OpenWeatherMap API. Follow these steps to set it up:

### 1. Get Your Free API Key

1. Go to [OpenWeatherMap](https://openweathermap.org/api)
2. Click "Sign Up" to create a free account
3. Verify your email address
4. Go to your [API Keys page](https://home.openweathermap.org/api_keys)
5. Copy your API key (it looks like: `a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6`)

### 2. Configure the API Key

1. Open `lib/services/weather_service.dart`
2. Find this line:
   ```dart
   static const String _apiKey = 'YOUR_API_KEY_HERE';
   ```
3. Replace `YOUR_API_KEY_HERE` with your actual API key:
   ```dart
   static const String _apiKey = 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6';
   ```

### 3. Test the Integration

1. Run the app: `flutter run`
2. Go to "Organize a Game"
3. Select a sport and field
4. Choose a date
5. You should see real weather icons for each time slot!

### 4. Features

✅ **Real Weather Data**: Accurate hourly forecasts  
✅ **Multiple Conditions**: Sunny, cloudy, rainy, thunderstorm, snow, fog  
✅ **iOS-style Icons**: Beautiful weather icons with appropriate colors  
✅ **Caching**: Weather data is cached for 6 hours to save API calls  
✅ **Fallback**: Falls back to dummy data if API fails  
✅ **Free Tier**: 1,000 API calls per day (plenty for testing)  

### 5. API Limits

- **Free Tier**: 1,000 calls/day
- **Caching**: Reduces API calls significantly
- **Cost**: $0 for the free tier
- **No Credit Card**: Required for free tier

### 6. Troubleshooting

**If weather icons don't show:**
- Check your internet connection
- Verify your API key is correct
- Check the debug console for error messages
- The app will fall back to dummy data if there are issues

**If you see "API key not configured":**
- Make sure you replaced `YOUR_API_KEY_HERE` with your actual key
- Restart the app after making changes

### 7. Weather Conditions Supported

| Condition | Icon | Color | Description |
|-----------|------|-------|-------------|
| Sunny | ☀️ | Orange | Clear sky |
| Partly Cloudy | ⛅ | Grey | Few clouds |
| Cloudy | ☁️ | Grey | Overcast |
| Rainy | 🌧️ | Blue | Rain/drizzle |
| Thunderstorm | ⚡ | Purple | Storms |
| Snow | ❄️ | Grey | Snow |
| Fog | 🌫️ | Grey | Fog/mist |
| Night | 🌙 | Purple | Night time |

Enjoy your real weather data! 🌤️
