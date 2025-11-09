//some minor changes to page title and preview

import SwiftUI

struct AuthorizedPeople: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var child: Child
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Authorized People for \(child.name)")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.bottom, 8)
                
                Text("Nothing here yet...")
            }
        }
        .navigationBarBackButtonHidden(true)
                .navigationBarItems(leading:
                                        Button(action: { //navigate back
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    //navigate back button styling:
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(Color("BlackFont"))
                                .font(.system(size: 20, weight: .bold))
                        }
                    }
                }
                )
    }
}

struct AuthorizedPeople_Previews: PreviewProvider {
    static var previews: some View {
        AuthorizedPeople(child: .constant(Child(id: "preview-id", name: "sarah", color: "blue", imageName: "penguin")))    }
}
