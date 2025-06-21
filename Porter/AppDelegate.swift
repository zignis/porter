//
//  AppDelegate.swift
//  Porter
//
//  Created by zignis on 20/06/25.
//

import AppKit
import Sparkle
import UserNotifications

let UPDATE_NOTIFICATION_IDENTIFIER = "PorterUpdateCheck"

@objc
class AppDelegate: NSObject, NSApplicationDelegate, SPUUpdaterDelegate,
    SPUStandardUserDriverDelegate, UNUserNotificationCenterDelegate,
    ObservableObject
{
    @Published var updaterController: SPUStandardUpdaterController!

    func applicationDidFinishLaunching(_: Notification) {
        // Make the app run in the background
        NSApp.setActivationPolicy(.accessory)
        UNUserNotificationCenter.current().delegate = self

        // Init updater
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true, // Start automatically
            updaterDelegate: self,
            userDriverDelegate: self,
        )
    }

    // Request for permissions to publish notifications for update alerts
    // This delegate method will be called when Sparkle schedules an update check in the future,
    // which may be a good time to request for update permission. This will be after the user has allowed
    // Sparkle to check for updates automatically. If you need to publish notifications for other reasons,
    // then you may have a more ideal time to request for notification authorization unrelated to update checking.
    func updater(
        _: SPUUpdater,
        willScheduleUpdateCheckAfterDelay _: TimeInterval,
    ) {
        UNUserNotificationCenter.current().requestAuthorization(options: [
            .badge, .alert, .sound,
        ]) { granted, error in
            if let error {
                print("[notification] authorization failed: \(error)")
                return
            }

            if granted {
                print("[notification] authorization granted")
            } else {
                print("[notification] authorization denied")
            }
        }
    }

    // Declares that we support gentle scheduled update reminders to Sparkle's standard user driver
    var supportsGentleScheduledUpdateReminders: Bool {
        true
    }

    func standardUserDriverWillHandleShowingUpdate(
        _: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState,
    ) {
        // When an update alert will be presented, place the app in the foreground
        // We will do this for updates the user initiated themselves too for consistency
        // When we later post a notification, the act of clicking a notification will also change the app
        // to have a regular activation policy. For consistency, we should do this if the user
        // does not click on the notification too.
        NSApp.setActivationPolicy(.regular)

        if !state.userInitiated {
            // And add a badge to the app's dock icon indicating one alert occurred
            NSApp.dockTile.badgeLabel = "1"

            // Post a user notification
            // For banner style notification alerts, this may only trigger when the app is currently inactive.
            // For alert style notification alerts, this will trigger when the app is active or inactive.
            do {
                let content = UNMutableNotificationContent()
                content.title = "A new update is available"
                content.body =
                    "Version \(update.displayVersionString) is now available"

                let request = UNNotificationRequest(
                    identifier: UPDATE_NOTIFICATION_IDENTIFIER,
                    content: content,
                    trigger: nil,
                )

                UNUserNotificationCenter.current().add(request)
            }
        }
    }

    func standardUserDriverDidReceiveUserAttention(
        forUpdate _: SUAppcastItem,
    ) {
        // Clear the dock badge indicator for the update
        NSApp.dockTile.badgeLabel = ""

        // Dismiss active update notifications if the user has given attention to the new update
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: [UPDATE_NOTIFICATION_IDENTIFIER])
    }

    func standardUserDriverWillFinishUpdateSession() {
        // Put app back in background when the user session for the update finished.
        // We don't have a convenient reason for the user to easily activate the app now.
        // Note this assumes there's no other windows for the app to show
        NSApp.setActivationPolicy(.accessory)
    }

    func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void,
    ) {
        if response.notification.request.identifier
            == UPDATE_NOTIFICATION_IDENTIFIER,
            response.actionIdentifier
            == UNNotificationDefaultActionIdentifier
        {
            // If the notificaton is clicked on, make sure we bring the update in focus
            // If the app is terminated while the notification is clicked on,
            // this will launch the application and perform a new update check.
            // This can be more likely to occur if the notification alert style is Alert rather than Banner
            updaterController.checkForUpdates(nil)
        }

        completionHandler()
    }
}
