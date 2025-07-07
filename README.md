# Station Inspection Score Card App

This is a Flutter application developed as part of an assignment to create a digital score card form for conducting cleanliness inspections at train stations. The app allows inspectors to record scores and remarks for various station parameters, saves submissions locally, attempts to sync them via a mock API, provides a history view, and generates PDF reports for past submissions.

This project demonstrates Flutter UI development, state management using Provider, local data persistence with Hive, making HTTP requests, handling app lifecycle for auto-save and sync, and PDF generation.

## Features Implemented

This project implements the core requirements and several bonus features:

### Core Requirements:

1.  **Score Card Form:**
    *   Implementation of all required sections (Platform Cleanliness, Urinals, etc.) and parameters based on the provided PDF (`1_SCORE CARD.pdf`).
    *   Input fields for Inspection Details (Location, Date, Train Number, Inspector Name, Designation, Overall Remarks).
    *   Interactive input for each parameter:
        *   Selecting a score from 0 to 10.
        *   Entering optional remarks.
2.  **Modern UI:**
    *   Intuitive and user-friendly mobile interface with enhanced styling (Themed colors, rounded inputs/cards).
    *   Uses native Date Picker for date input.
    *   Custom horizontal selectable list for score selection (more intuitive than a dropdown).
    *   Multi-line text fields for remarks.
    *   Uses `ExpansionTile` to make score sections collapsible, improving navigation on mobile screens.
3.  **State Management:**
    *   Uses the `provider` package to manage the state of the `ScoreCardData` as the form is being filled.
    *   Data is held in memory via the provider until submission or clearing.
4.  **Mock Submission Endpoint:**
    *   On submission, the collected data is formatted as a JSON object.
    *   An HTTP POST request is sent to a mock endpoint (`https://httpbin.org/post`).

### Bonus Features Implemented:

1.  **Local Data Persistence (Hive):**
    *   All submitted forms are saved locally on the device using the Hive NoSQL database.
    *   Data is persisted even if the app is closed.
2.  **Offline Data Entry (Partially):**
    *   Submissions are *always* saved locally first. If the HTTP submission fails (due to no network or server error), the data is safely stored locally and marked as "Pending Sync".
    *   (Note: Background sync using platform APIs like WorkManager is not implemented due to complexity and the single-file constraint, but foreground sync is attempted on app resume).
3.  **Submission History View:**
    *   A dedicated screen accessible from the main form's AppBar displays a list of all locally saved submissions.
    *   Each list item shows key details (Location, Train Number, Date) and its sync status (Synced/Pending Sync).
    *   Option to delete local submissions from the history list.
4.  **Submission Detail View:**
    *   Tapping a submission in the history list navigates to a detail screen.
    *   This screen loads the full submission data from Hive and displays all details (header info, all parameter scores, and remarks) in a read-only format.
    *   Displays the sync status in the detail view.
5.  **PDF Generation & Preview:**
    *   On the Submission Detail screen, a PDF icon button allows generating a PDF report of that specific submission.
    *   Uses the `printing` package to show a native-like preview dialog, allowing the user to view, share, or print the PDF.
    *   A PDF preview button is also available on the main form for the *current* unsaved data.
6.  **Form Auto-Save Draft:**
    *   Uses `WidgetsBindingObserver` to listen for app lifecycle changes.
    *   The *currently active* form data is automatically saved as a draft to Hive when the app goes into the background (`AppLifecycleState.paused` or `inactive`).
    *   When the app is resumed (`AppLifecycleState.resumed`) and the form screen is loaded, it checks for a saved draft and prompts the user to load it.
    *   The draft is cleared on successful form submission or when the user explicitly clears the form.
7.  **Foreground Sync:**
    *   When the app resumes (`AppLifecycleState.resumed`), the `ScoreCardFormState` checks the Hive box for any submissions marked as "Pending Sync" and attempts to resend them via HTTP.

## Project Setup

1.  **Prerequisites:** Ensure you have the Flutter SDK installed and configured.
2.  **Clone or Download:** Clone this repository or download the project ZIP file.
3.  **Navigate:** Open a terminal or command prompt and navigate to the project directory (`clean_train_scorecard`).
4.  **Get Dependencies:** Run the following command to fetch the required packages:
    ```bash
    flutter pub get
    ```
    *(Note: If you encounter `MissingPluginException` errors after adding plugins like `path_provider` or `hive`, perform a full cold restart by stopping the app completely and running `flutter run` again).*
5.  **Single File:** Note that all the application code, including models, state management, and UI screens, is contained within a single file: `lib/main.dart` as per the assignment constraint.

## Running the App

To run the application on an emulator or physical device:

1.  Make sure a device or emulator is connected and recognized by `flutter doctor`.
2.  In the project directory, run:
    ```bash
    flutter run
    ```
    *(This will build and launch the application).*

## Usage

1.  **Fill the Form:** Enter details in the header fields. Select scores (0-10) by tapping the numbers and add optional remarks for each parameter. Use the date picker for the Inspection Date field.
2.  **Preview PDF:** Tap the PDF icon in the AppBar on the main form to see a PDF preview of the data you've entered so far (does not save or submit).
3.  **Clear Form:** Tap the broom icon in the AppBar to reset the current form data, prompting for confirmation if there are unsaved changes.
4.  **Submit:** Tap the "Submit Score Card" button.
    *   Validation will check required fields.
    *   On success, the data is saved locally (to Hive), an attempt is made to send it via HTTP to the mock endpoint, the form is cleared, and the draft is deleted.
    *   You will see a success or failure message (indicating local save and/or HTTP sync status).
5.  **Auto-Save:** If you leave the app without submitting (e.g., press the home button), the current form state will be saved as a draft. When you open the app again, you'll be prompted to load the draft.
6.  **Submission History:** Tap the History icon (clock) in the AppBar.
    *   View a list of all past submissions stored locally.
    *   Cloud icons indicate sync status (orange = pending, green = synced).
    *   Tap the trash icon to delete a submission.
7.  **View Submission Details:** Tap a submission entry in the history list.
    *   See the complete details of that specific submission.
    *   Sync status and Submission ID are displayed.
8.  **View/Share PDF Report:** On the Submission Detail screen, tap the PDF icon to generate and preview the PDF report for that saved submission.

## API Documentation (Postman)

The application sends data via an HTTP POST request to the mock endpoint:

`POST https://httpbin.org/post` (or your `webhook.site` URL)

**Headers:**
*   `Content-Type: application/json`

**Request Body (JSON Payload):**

The structure mirrors the `ScoreCardData.toJson()` method in the code. An example payload looks like this:

```json
{
  "submissionId": "2023-10-27T10:30:00.123456", // Unique ID (timestamp)
  "location": "Sample Station",
  "date": "2023-10-27", // Formatted YYYY-MM-DD
  "inspectorName": "John Doe",
  "inspectorDesignation": "Railway Officer",
  "trainNo": "12309",
  "remarksOverall": "Overall good cleanliness observed.",
  "isSynced": false, // Status on the client side
  "sections": [
    {
      "section": "Platform Cleanliness",
      "parameters": [
        {
          "parameter": "General cleanliness",
          "score": 8,
          "remarks": "Minor litter."
        },
        // ... other parameters for this section
      ]
    },
    // ... other sections and their parameters
  ]
}
