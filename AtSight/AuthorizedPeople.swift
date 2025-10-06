import SwiftUI

struct AuthorizedPeople: View {
    @Environment(\.presentationMode) var presentationMode
    var body: some View {
        VStack {
            
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
        AuthorizedPeople()
    }
}
