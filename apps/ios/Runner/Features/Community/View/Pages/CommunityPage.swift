import SwiftUI

struct CommunityPage: View {

  var body: some View {
    List {
      Label("Places", systemImage: "mappin.and.ellipse")
      Label("Community fund", systemImage: "heart.circle")
    }
    .navigationTitle("Community")
    .navigationBarTitleDisplayMode(.inline)
  }
}
