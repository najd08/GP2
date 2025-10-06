//
//  HomeAndChildDetail.swift
//  Atsight
//
//  Final merged version:
//  - Uses AddZonePage(childID:) (Riyam’s fix)
//  - Includes ZoneAlertSimulation link
//  - Dark mode safe back button
//  - LazyVGrid for navigation links
//  - Debug “simulate linking” section
//

import SwiftUI
import MapKit
import FirebaseAuth
import FirebaseFirestore
import AVFoundation

// MARK: - ChildDetailView
struct ChildDetailView: View {
    @State var child: Child
    @Environment(\.presentationMode) var presentationMode
    @State private var guardianID: String = Auth.auth().currentUser?.uid ?? ""
    @State private var viewRefreshToken = UUID()

    // 2 flexible columns for the grid
    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    // Linked state
    private var isLinked: Bool {
        UserDefaults.standard.bool(forKey: "linked_\(child.id)")
    }

    // Parent display name (from email prefix)
    private var parentDisplayName: String {
        if let email = Auth.auth().currentUser?.email {
            return email.components(separatedBy: "@").first ?? "Parent"
        }
        return "Parent"
    }

    var body: some View {
        VStack {
            // MARK: Header
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color("BlackFont")) // dark mode safe
                        .font(.system(size: 20, weight: .bold))
                }

                Spacer()

                HStack(spacing: 6) {
                    Text(child.name)
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(Color("BlackFont"))

                    if isLinked {
                        Image(systemName: "link.circle.fill")
                            .foregroundColor(Color("Blue"))
                            .font(.title3)
                            .accessibilityLabel("Linked")
                    }
                }

                Spacer()
                Spacer().frame(width: 24)
            }
            .padding()
            .padding(.top, -10)

            // MARK: Not Linked
            if !isLinked {
                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Text("Link your child's watch")
                            .font(.headline)
                            .foregroundColor(Color("BlackFont"))
                        Text("Please link the watch first to enable location and other features.")
                            .font(.footnote)
                            .foregroundColor(Color("ColorGray"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }

                    NavigationLink(
                        destination: ParentLinkView(
                            childId: child.id,
                            childName: child.name,
                            parentName: parentDisplayName
                        )
                    ) {
                        VStack {
                            Image(systemName: "link")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .foregroundColor(Color("Blue"))
                            Text("Link Watch")
                                .font(.headline)
                                .foregroundColor(Color("BlackFont"))
                        }
                        .frame(width: 300, height: 140)
                        .background(Color("BgColor"))
                        .cornerRadius(20)
                        .shadow(radius: 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color("ColorGray"), lineWidth: 1)
                        )
                    }

                    // Debug: simulate linking
                    Text("Simulate linking for testing")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                        .onTapGesture {
                            UserDefaults.standard.set(true, forKey: "linked_\(child.id)")
                            viewRefreshToken = UUID() // force refresh
                        }

                    Spacer()
                }
            } else {
                // MARK: Linked Grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        NavigationLink(destination: ParentChildChatView(child: child, parentName: parentDisplayName)) {
                            gridButtonContent(icon: "bubble.left.and.bubble.right.fill", title: "Chat", color: Color("Buttons"))
                        }

                        NavigationLink(destination: ChildLocationView(child: child)) {
                            gridButtonContent(icon: "location.fill", title: "View Last Location", color: Color("Blue"))
                        }

                        NavigationLink(destination: EditChildProfile(guardianID: guardianID, child: $child)) {
                            gridButtonContent(icon: "figure.child.circle", title: "Child Profile", color: Color("ColorGreen"))
                        }

                        NavigationLink(destination: LocationHistoryView(childID: child.id)) {
                            gridButtonContent(icon: "clock.arrow.circlepath", title: "Location History", color: Color("ColorPurple"))
                        }

                        NavigationLink(destination: AddZonePage(childID: child.id)) {
                            gridButtonContent(icon: "mappin.and.ellipse", title: "Zones Setup", color: Color("ColorRed"))
                        }

                        NavigationLink(destination: ZoneAlertSimulation(childID: child.id)) {
                            gridButtonContent(icon: "map.circle", title: "Zones Alert Test", color: Color("ColorRed"))
                        }
                    }
                    .padding()
                }
                .background(Color("BgColor"))
                .cornerRadius(15)
                .id(viewRefreshToken)
            }
        }
        .background(Color("BgColor").ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            guardianID = Auth.auth().currentUser?.uid ?? ""
            viewRefreshToken = UUID()
        }
    }

    // MARK: Grid Button
    @ViewBuilder
    private func gridButtonContent(icon: String, title: String, color: Color) -> some View {
        VStack {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .foregroundColor(color)
            Text(title)
                .font(.headline)
                .foregroundColor(Color("BlackFont"))
                .multilineTextAlignment(.center)
        }
        .frame(width: (UIScreen.main.bounds.width / 2) - 30, height: 140)
        .background(Color("BgColor"))
        .cornerRadius(20)
        .shadow(radius: 10)
    }
}

// MARK: - HomeView
struct HomeView: View {
    @Binding var selectedChild: Child?
    @Binding var expandedChild: Child?
    @State private var firstName: String = "Guest"
    @State private var children: [Child] = []

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                HStack {
                    Spacer()
                    Image("Image 1")
                        .resizable()
                        .frame(width: 140, height: 130)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.top)

                VStack(alignment: .leading, spacing: 20) {
                    Text("Hello \(firstName)")
                        .font(.largeTitle).bold()
                        .foregroundColor(Color("Blue"))
                        .padding(.top, 20)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("View your kids' locations.")
                            .font(.title3)
                            .foregroundColor(Color("BlackFont"))
                            .fontWeight(.medium)

                        Text("Stay connected and informed about their well-being.")
                            .font(.body)
                            .foregroundColor(Color("ColorGray"))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack {
                        NavigationLink(destination: AddChildView(fetchChildrenCallback: fetchChildrenFromFirestore)) {
                            Text("Add child")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .foregroundColor(Color("Blue"))
                                .background(Color("BgColor"))
                                .cornerRadius(25)
                                .shadow(radius: 5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(Color("ColorGray"), lineWidth: 1)
                                )
                        }
                        .padding(.leading, 250)
                    }

                    ScrollView {
                        VStack(spacing: 15) {
                            ForEach(children) { child in
                                NavigationLink(destination: ChildDetailView(child: child)) {
                                    ChildCardView(child: child, expandedChild: $expandedChild)
                                        .padding(.top)
                                }
                                .onDisappear {
                                    fetchChildrenFromFirestore()
                                }
                            }
                        }
                    }
                    .padding(.top, 3)
                }
                .onAppear {
                    fetchUserName()
                    fetchChildrenFromFirestore()

                    if let uid = Auth.auth().currentUser?.uid {
                        UserDefaults.standard.set(uid, forKey: "guardianID")
                        print("✅ Updated guardianID in UserDefaults: \(uid)")
                    }
                }
            }
            .padding(.horizontal, 10)
            .background(Color("BgColor").ignoresSafeArea())
        }
    }

    // MARK: Firestore
    func fetchChildrenFromFirestore() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        db.collection("guardians").document(userId).collection("children").getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching children: \(error.localizedDescription)")
            } else {
                DispatchQueue.main.async {
                    self.children = snapshot?.documents.compactMap { doc in
                        let data = doc.data()
                        return Child(
                            id: doc.documentID,
                            name: data["name"] as? String ?? "Unknown",
                            color: data["color"] as? String ?? "gray",
                            imageName: data["imageName"] as? String
                        )
                    } ?? []
                }
            }
        }
    }

    func fetchUserName() {
        if let userId = Auth.auth().currentUser?.uid {
            let db = Firestore.firestore()
            db.collection("guardians").document(userId).getDocument { document, _ in
                if let document = document, document.exists {
                    if let fetchedFirstName = document.data()?["FirstName"] as? String {
                        firstName = fetchedFirstName
                    }
                }
            }
        }
    }
}

// MARK: - ParentChildChatView
struct ParentChildChatView: View {
    let child: Child
    let parentName: String

    @State private var messages: [ChatMessage] = []
    @State private var listener: ListenerRegistration?
    @State private var textDraft: String = ""
    @StateObject private var audio = URLAudioPlayer()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Chat with \(child.name)")
                    .font(.headline)
                    .foregroundColor(Color("BlackFont"))
                Spacer()
            }
            .padding()
            .background(Color("BgColor"))

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { msg in
                            if msg.type == .text {
                                TextBubble(
                                    text: msg.text ?? "",
                                    isMine: msg.sender == "parent",
                                    timestamp: msg.timestamp
                                )
                                .id(msg.id)
                            } else if msg.type == .voice {
                                VoiceBubble(
                                    isMine: msg.sender == "parent",
                                    duration: msg.duration ?? 0,
                                    timestamp: msg.timestamp,
                                    isPlaying: audio.isPlaying(url: msg.downloadURL),
                                    playPause: { audio.toggle(urlString: msg.downloadURL) }
                                )
                                .id(msg.id)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }

            HStack(spacing: 8) {
                TextField("Type a message…", text: $textDraft)
                    .textFieldStyle(.roundedBorder)
                    .disableAutocorrection(true)

                Button {
                    sendText()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                }
                .disabled(textDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(12)
            .background(Color("BgColor"))
        }
        .background(Color("BgColor").ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: startListening)
        .onDisappear(perform: stopListening)
    }

    private func startListening() {
        let db = Firestore.firestore()
        listener = db.collection("messages")
            .whereField("childId", isEqualTo: child.id)
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snap, _ in
                guard let docs = snap?.documents else { return }
                messages = docs.compactMap { d in
                    let data = d.data()
                    let typeStr = (data["type"] as? String) ?? "text"
                    let type: ChatMessage.Kind = (typeStr == "voice") ? .voice : .text

                    return ChatMessage(
                        id: d.documentID,
                        type: type,
                        sender: (data["sender"] as? String) ?? "watch",
                        text: data["text"] as? String,
                        duration: data["duration"] as? Double,
                        downloadURL: data["downloadURL"] as? String,
                        timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }
            }
    }

    private func stopListening() {
        listener?.remove(); listener = nil
        audio.stopAll()
    }

    private func sendText() {
        let msg = textDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty else { return }
        textDraft = ""

        let db = Firestore.firestore()
        db.collection("messages").addDocument(data: [
            "type": "text",
            "childId": child.id,
            "sender": "parent",
            "text": msg,
            "timestamp": FieldValue.serverTimestamp()
        ])
    }
}

// MARK: - Models & UI
struct ChatMessage: Identifiable {
    enum Kind { case text, voice }
    let id: String
    let type: Kind
    let sender: String
    let text: String?
    let duration: Double?
    let downloadURL: String?
    let timestamp: Date
}

struct TextBubble: View {
    let text: String
    let isMine: Bool
    let timestamp: Date

    var body: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
            HStack {
                if isMine { Spacer() }
                Text(text)
                    .font(.body)
                    .foregroundColor(isMine ? .white : Color("BlackFont"))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isMine ? Color("Blue") : Color("BgColor"))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isMine ? Color.clear : Color("ColorGray").opacity(0.4), lineWidth: 1)
                    )
                if !isMine { Spacer() }
            }
            Text(Self.formatter.string(from: timestamp))
                .font(.caption2)
                .foregroundColor(Color("ColorGray"))
                .padding(isMine ? .trailing : .leading, 6)
        }
    }

    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
}

struct VoiceBubble: View {
    let isMine: Bool
    let duration: Double
    let timestamp: Date
    let isPlaying: Bool
    let playPause: () -> Void

    var body: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
            HStack {
                if isMine { Spacer() }
                HStack(spacing: 8) {
                    Button(action: playPause) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 22))
                    }
                    Text(Self.formatDuration(duration))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isMine ? Color("Blue") : Color("BgColor"))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isMine ? Color.clear : Color("ColorGray").opacity(0.4), lineWidth: 1)
                )
                if !isMine { Spacer() }
            }
            Text(TextBubble.formatter.string(from: timestamp))
                .font(.caption2)
                .foregroundColor(Color("ColorGray"))
                .padding(isMine ? .trailing : .leading, 6)
        }
    }

    private static func formatDuration(_ sec: Double) -> String {
        let s = Int(sec.rounded())
        return String(format: "%02d:%02d", s/60, s%60)
    }
}

// MARK: - Audio Player
final class URLAudioPlayer: ObservableObject {
    @Published private var currentURL: String?
    private var player: AVPlayer?

    func isPlaying(url: String?) -> Bool {
        guard let url, url == currentURL, let p = player else { return false }
        return p.rate > 0
    }

    func toggle(urlString: String?) {
        guard let urlString, let url = URL(string: urlString) else { return }
        if isPlaying(url: urlString) {
            player?.pause()
        } else {
            player = AVPlayer(url: url)
            currentURL = urlString
            player?.play()
        }
    }

    func stopAll() {
        player?.pause()
        player = nil
        currentURL = nil
    }
}

#Preview("Home") {
    HomeView(selectedChild: .constant(nil), expandedChild: .constant(nil)).environmentObject(AppState())
}
