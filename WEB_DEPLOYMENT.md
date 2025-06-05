# Sororia - Web Deployment Guide

This Flutter app has been optimized to work on web platforms. Below are the key changes made and deployment instructions.

## Changes Made for Web Compatibility

### 1. Firebase Messaging (Notifications)
- **Mobile**: Full Firebase Cloud Messaging support with background/foreground message handling
- **Web**: Notifications are disabled as they require complex service worker setup and have limited browser support
- **Implementation**: Created `NotificationService` that conditionally handles messaging based on platform

### 2. Device Orientation
- **Mobile**: Restricts to portrait orientation only
- **Web**: No orientation restrictions (web browsers handle this naturally)

### 3. Location Services
- **Mobile**: Full Geolocator permission handling
- **Web**: Simplified location access with graceful error handling for browser permission prompts
- **Error Handling**: User-friendly messages for location access denial

### 4. Responsive Design
- Created `WebConfig` service for responsive breakpoints
- Added responsive containers and layouts
- Optimized for mobile, tablet, and desktop web experiences

### 5. Web-Specific Optimizations
- Updated `manifest.json` with proper PWA configuration
- Enhanced `index.html` with better SEO meta tags
- Removed mobile-specific splash screen configurations from web build

## Key Features That Work on Web

✅ **User Authentication** (Firebase Auth)
✅ **Firestore Database** (Cloud Firestore) 
✅ **Interactive Maps** (flutter_map with OpenStreetMap)
✅ **Location Services** (with browser permission handling)
✅ **News Feed** (API integration)
✅ **Complaint System** (full CRUD operations)
✅ **Petition System** (full CRUD operations)
✅ **Chatbot Integration** (Gemini AI)
✅ **Statistics Dashboard** (fl_chart)
✅ **Routing & Navigation** (safest route calculation)
✅ **Theme Support** (light/dark mode)
✅ **Responsive Design** (mobile, tablet, desktop)

❌ **Push Notifications** (disabled for web)
❌ **Device Orientation Lock** (not applicable for web)

## Building for Web

### Development Build
```bash
flutter run -d web-server
```

### Production Build
```bash
flutter build web --release
```

The built files will be in `build/web/` directory.

## Deployment Options

### 1. Firebase Hosting (Recommended)
```bash
npm install -g firebase-tools
firebase login
firebase init hosting
# Select build/web as public directory
firebase deploy
```

### 2. GitHub Pages
1. Copy contents of `build/web/` to your GitHub Pages repository
2. Ensure `index.html` is in the root directory
3. Enable GitHub Pages in repository settings

### 3. Netlify
1. Drag and drop the `build/web/` folder to Netlify
2. Or connect your GitHub repository for automatic deployments

### 4. Vercel
```bash
npx vercel
# Select build/web as the output directory
```

## Environment Variables

Ensure your `.env` file is properly configured with:
```env
GEMINI_API_KEY=your_gemini_api_key
SERPER_API_KEY=your_serper_api_key
```

## Firebase Configuration

Make sure your Firebase project has:
- ✅ Authentication enabled (Email/Password, Google Sign-In, Phone Auth)
- ✅ Firestore Database configured
- ✅ Web app registered in Firebase console
- ✅ `firebase_options.dart` properly generated

## Browser Compatibility

**Supported Browsers:**
- ✅ Chrome 88+
- ✅ Firefox 85+
- ✅ Safari 14+
- ✅ Edge 88+

**Note**: Location services require HTTPS in production for security reasons.

## Performance Considerations

1. **Tree Shaking**: Icons are automatically tree-shaken to reduce bundle size
2. **Lazy Loading**: Routes are loaded on-demand
3. **Image Optimization**: Use WebP format for better compression
4. **Caching**: Flutter web automatically handles caching for static assets

## Testing Web Version

1. Run `flutter run -d web-server`
2. Open the provided localhost URL
3. Test location permissions in browser
4. Verify all features work without notifications
5. Test responsive design on different screen sizes

## Troubleshooting

### Location Issues
- Ensure HTTPS in production
- Check browser location permissions
- Test with different browsers

### Firebase Issues
- Verify Firebase configuration
- Check console for CORS errors
- Ensure Firestore rules allow web access

### Performance Issues
- Use `flutter build web --release` for production
- Enable gzip compression on your hosting provider
- Consider using a CDN for static assets

## Security Notes

- All Firebase operations use proper security rules
- No sensitive API keys are exposed in client-side code
- HTTPS is required for location services and Firebase Auth
