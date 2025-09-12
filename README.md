# **smart_civic_watch user mobile app**
---------------------------------------------------------
**Prerequisites**
-Flutter SDK: Install Flutter on your development machine

-Android Studio: With Flutter and Dart plugins installed

-Firebase Account: For backend services (optional for demo)

-Physical Device or Emulator: To run the application
----------------------------------------------------------
**Step-by-Step Setup Instructions**
1. Clone the Repository
   git clone https://github.com/mclawrenc3/smart-civic-watch-official.git
   cd smart-civic-watch
   
2. Install Dependencies
   flutter pub get

3. Configure Firebase (Optional for Demo)
If you want to use the full functionality:

Create a Firebase project at https://console.firebase.google.com/

Enable Authentication, Firestore Database, and Storage

Download the configuration files:

google-services.json for Android (place in android/app/)

GoogleService-Info.plist for iOS (place in ios/Runner/)

4. Run the Application
   -For Android
    flutter run -d android
    
    - For iOS
    flutter run -d ios
---------------------------------------------------------------
**Demo Accounts for Testing**
you can sign in or sign up with gmail accounts
---------------------------------------------------------------
**How to Use the System**
1. Authentication
Open the app and you'll see the login screen

Use any gmail account above to log in

Or create a new account using the registration option

2. Main Dashboard
After logging in, you'll see:

Interactive map showing your location

Quick access buttons to all features

Navigation icons in the header

3. Reporting an Incident
Tap the "Report Incident" button

Add a title and description

Attach media (photo or video) using the dropdown

Submit the report

4. Viewing Emergency Alerts
Tap the "Emergency Alerts" button

View real-time alerts from the community

Filter between "My Reports" and "Community" alerts

Interact with alerts (like, comment, share)

5. Managing Emergency Contacts
Tap the "Emergency Contacts" button

View pre-loaded emergency numbers

Add new contacts using the + button

Tap any contact to call directly

6. Making Donations
Tap the "Donations" button

Select an amount or enter a custom amount

Choose a payment method

Complete the donation process

7. Using the Map
The map automatically shows your current location
Your location is shown with a blue dot





