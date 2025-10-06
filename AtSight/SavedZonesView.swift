// added filter ✅
// edit name to zones ✅
//fixed delete and fetch zones functions ✅
//cleaned code and removed redundancy, now the redundant functions are called from "ZonesViewModel" ✅
//added "° N" and "° E" in line 237 to zone cords for better UX ✅

import SwiftUI
import MapKit
import Firebase
import FirebaseFirestore
import FirebaseAuth


//MARK: - Variables:
struct SavedZonesView: View {
    @Environment(\.presentationMode) var presentationMode
    
    // This view receives the ViewModel instance from the previous view.
    @ObservedObject var viewModel: ZonesViewModel

    @State private var isProcessing = false
    @State private var alertType: AlertType?
    
    // Edit Name State Variables
    @State private var showingEditSheet = false
    @State private var selectedZone: Zone?
    @State private var newZoneName = ""
    
    //alert types to give user feedback
    enum AlertType: Identifiable {
        case delete(Zone)
        case success
        case editSuccess // Added edit success alert

        var id: String {
            switch self {
            case .delete(let zone): return "delete_\(zone.id)"
            case .success: return "success"
            case .editSuccess: return "editSuccess"
            }
        }
    }
    
    //MARK: - Zones filtering setup:
    // Filter State Variable
    @State private var selectedFilter: FilterOption = .all
    
    //Filter Options Enum:
    enum FilterOption: String, CaseIterable {
        case all = "All"
        case safe = "Safe"
        case unsafe = "Unsafe"
    }
    
    //Computed Property for Filtered Zones
    var filteredZones: [Zone] {
        switch selectedFilter {
        case .all:
            return viewModel.zones
        case .safe:
            return viewModel.zones.filter { $0.isSafeZone }
        case .unsafe:
            return viewModel.zones.filter { !$0.isSafeZone }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            //Filter Segmented Control
            Picker("Filter", selection: $selectedFilter) {
                ForEach(FilterOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.vertical, 10)
            
            //listing zones (by filter) and customizing each item in the list:
            List {
                ForEach(filteredZones) { zone in
                    ZoneRow(
                        zone: zone,
                        onEdit: { editZoneName(zone: zone) },
                        onDelete: { alertType = .delete(zone) }
                    )
                }
            }
        }

        //customizing the back button:
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
            Button(action: {
                self.presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(Color("BlackFont"))
                    .font(.system(size: 20, weight: .bold))
            }
        )
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Saved Zones")
                    .font(.system(size: 24, weight: .bold))
            }
        }
        .overlay(
            Group {
                if isProcessing {
                    Color.black.opacity(0.2)
                        .edgesIgnoringSafeArea(.all)
                        .overlay(
                            ProgressView("Processing...")
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                        )
                }
            }
        )
        // MARK: - Edit Name Sheet
        //this sheet appears when the user wants to edit the zone's name.
        .sheet(isPresented: $showingEditSheet) {
            NavigationView {
                VStack(spacing: 20) {
                    Text("Edit Zone Name")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    TextField("Zone Name", text: $newZoneName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    Spacer()
                }
                .navigationBarItems(
                    leading: Button("Cancel") {
                        showingEditSheet = false
                    },
                    trailing: Button("Save") {
                        saveZoneNameChanges()
                    }
                    .disabled(newZoneName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                )
            }
        }
        .onAppear {
            viewModel.fetchZones() //fetch zones when the page loads
        }
        .alert(item: $alertType) { alert in
            switch alert {
            case .delete(let zone):
                return Alert(
                    title: Text("Confirm Deletion"),
                    message: Text("Are you sure you want to delete this zone?"),
                    primaryButton: .destructive(Text("Delete")) {
                        deleteSelectedZone(zone)
                    },
                    secondaryButton: .cancel()
                )
            case .success:
                return Alert(
                    title: Text("Success"),
                    message: Text("Zone deleted successfully."),
                    dismissButton: .default(Text("OK"))
                )
            // Added edit success alert case
            case .editSuccess:
                return Alert(
                    title: Text("Success"),
                    message: Text("Zone name updated successfully."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    // MARK: Firebase Functions are now local wrappers that call the ViewModel

    // MARK: - Edit Name Functions:
    //Sets up the edit sheet with the selected zone's current name
    func editZoneName(zone: Zone) {
        selectedZone = zone
        newZoneName = zone.zoneName
        showingEditSheet = true
    }
    
    //Updates the zone name by calling the ViewModel.
    func saveZoneNameChanges() {
        guard let zone = selectedZone else { return }
        
        isProcessing = true
        showingEditSheet = false
        
        viewModel.updateZoneNameInFirebase(zoneToUpdate: zone, newName: newZoneName)
        
        // The ViewModel updates the @Published zones array, which will refresh the UI.
        // We can show the success alert after a short delay.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isProcessing = false
            alertType = .editSuccess
        }
    }

    // MARK: - Delete Zone Function
    //Deletes the zone by calling the ViewModel.
    func deleteSelectedZone(_ zone: Zone) {
        viewModel.deleteZone(zone)
        alertType = .success
    }
}

// MARK: - Zone Row Subview
// Extracted row to fix type-checking error in SwiftUI
//these define how each zone item is displayed in the list:
struct ZoneRow: View {
    let zone: Zone
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: "mappin")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 10, height: 10)
                    .padding(.trailing, 10)

                VStack(alignment: .leading) {
                    Text(zone.zoneName)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(" \(zone.coordinate.latitude)° N, \(zone.coordinate.longitude)° E")
                        .foregroundColor(.gray)
                }

                Spacer()

                Text(zone.isSafeZone ? "Safe" : "Unsafe")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(6)
                    .background(zone.isSafeZone ? Color.green : Color.red)
                    .cornerRadius(10)
            }

            HStack {
                //edit zone name button:
                Button(action: onEdit) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Edit Name")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                //delete zone button:
                Button(action: onDelete) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Zone")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }
}

struct SavedZonesView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview now requires a viewModel instance
        SavedZonesView(viewModel: ZonesViewModel(childID: "sampleChildID"))
    }
}
