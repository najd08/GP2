//Changed by Riyam: each child's creaction will now add a notifications subcollection and a fixed "settings" document in it ✅
//NOTE: i've also change the Firebase rules! now everything works fine 👍🏻
//The newly created children will now get a nil value for their isSafeZone notification value ✅

import FirebaseFirestore

func saveChildToFirestore(guardianID: String, child: Child, completion: @escaping (Result<Void, Error>) -> Void) {
    let db = Firestore.firestore()

    let childRef = db.collection("guardians")
        .document(guardianID)
        .collection("children")
        .document(child.id)

    var childData: [String: Any] = [
        "name": child.name,
        "color": child.color
    ]

    if let imageName = child.imageName {
        childData["imageName"] = imageName
    }

    print("🚀 Starting to create child...")

    childRef.setData(childData) { error in
        if let error = error {
            print("❌ Error adding child: \(error.localizedDescription)")
            completion(.failure(error))
        } else {
            print("✅ Step 1: Child added successfully.")

            let timestamp = Timestamp(date: Date())

            // Create initial documents for other child collections
            let updatedEntry: [String: Any] = [
                "coordinate": [0.0, 0.0],
                "timestamp": timestamp,
                "zoneName": "Initial",
                "isSafeZone": true
            ]

            let collections = ["liveLocation", "locationHistory", "safeZone", "unSafeZone"]
            let group = DispatchGroup()
            var encounteredError: Error? = nil

            for collection in collections {
                group.enter()
                let collectionRef = childRef.collection(collection).document("init")
                collectionRef.setData(updatedEntry) { error in
                    if let error = error {
                        print("❌ Error creating \(collection): \(error.localizedDescription)")
                        encounteredError = error
                    } else {
                        print("✅ \(collection) created with initial entry.")
                    }
                    group.leave()
                }
            }

            // MARK: - Create notifications/settings doc for the child
            group.enter()
            let notificationSettingsRef = childRef.collection("notifications").document("settings")
            let defaultNotificationSettings: [String: Any] = [
                "safeZoneAlert": true,
                "unsafeZoneAlert": true,
                "lowBatteryAlert": true,
                "watchRemovedAlert": true,
                "newAuthorAccount": true,
                "sound": "default_sound"
            ]

            notificationSettingsRef.setData(defaultNotificationSettings) { error in
                if let error = error {
                    print("❌ Error creating child notifications/settings: \(error.localizedDescription)")
                    encounteredError = error
                } else {
                    print("✅ Child notifications/settings created with default values.")
                }
                group.leave()
            }

            // MARK: - This is the missing part: Create a notification for the GUARDIAN
            group.enter()
            let notificationRef = db.collection("guardians")
                .document(guardianID)
                .collection("notifications")
                .document() // Creates a new document with a unique ID

            let notificationData: [String: Any] = [
                "title": "New Child Added",
                "body": "Child \(child.name) was added successfully.",
                "timestamp": timestamp
                // "isSafeZone" is intentionally omitted here to represent a nil value.
            ]

            notificationRef.setData(notificationData) { error in
                if let error = error {
                    print("❌ Error creating guardian notification: \(error.localizedDescription)")
                    encounteredError = error
                } else {
                    print("✅ Guardian notification created for the new child.")
                }
                group.leave()
            }


            group.notify(queue: .main) {
                if let error = encounteredError {
                    completion(.failure(error))
                } else {
                    print("✅ All initial documents created successfully.")
                    completion(.success(()))
                }
            }
        }
    }
}
