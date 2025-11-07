//
//  AboutAppView.swift
//  Skyscraper
//
//  About the app view showing developer information
//

import SwiftUI
#if os(iOS)
import MessageUI
#endif
#if os(macOS)
import AppKit
#endif

struct AboutAppView: View {
    @EnvironmentObject var theme: AppTheme
    @Environment(\.dismiss) private var dismiss
    #if os(iOS)
    @State private var showingMailCompose = false
    @State private var showingMailAlert = false
    #endif

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 60))
                        .foregroundColor(theme.accentColor)

                    Text("This app was created by Cameron Banga. He hopes you like it!")
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Text("Seeing an issue? Something not working correctly? Please screenshot and email to hi@cameron.software")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 40, leading: 0, bottom: 20, trailing: 0))
            }

            Section {
                Button(action: emailDeveloper) {
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(theme.accentColor)
                            .frame(width: 20, alignment: .center)

                        Text("Email Developer")
                            .foregroundColor(.primary)

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                NavigationLink(destination: ProfileView(actor: "cameronbanga.com")) {
                    HStack {
                        Image(systemName: "cloud")
                            .foregroundColor(.blue)
                            .frame(width: 20, alignment: .center)

                        Text("Follow on Bluesky")

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Button(action: openWebsite) {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                            .frame(width: 20, alignment: .center)

                        Text("Visit his Website")
                            .foregroundColor(.primary)

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("About This App")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingMailCompose) {
            MailComposeView(
                recipient: "hi@cameron.software",
                subject: "Skyscraper Feedback"
            )
        }
        .alert("Cannot Send Email", isPresented: $showingMailAlert) {
            Button("OK") { }
        } message: {
            Text("Please configure an email account in Settings or contact hi@cameron.software directly.")
        }
        #endif
    }

    private func emailDeveloper() {
        #if os(iOS)
        if MFMailComposeViewController.canSendMail() {
            showingMailCompose = true
        } else {
            showingMailAlert = true
        }
        #else
        // macOS: Open default email client
        let email = "hi@cameron.software"
        let subject = "Skyscraper Feedback"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mailtoURL = "mailto:\(email)?subject=\(encodedSubject)"

        if let url = URL(string: mailtoURL) {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    private func openWebsite() {
        if let url = URL(string: "https://cameron.software") {
            #if os(iOS)
            UIApplication.shared.open(url)
            #else
            NSWorkspace.shared.open(url)
            #endif
        }
    }
}

#if os(iOS)
struct MailComposeView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients([recipient])
        composer.setSubject(subject)
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView

        init(_ parent: MailComposeView) {
            self.parent = parent
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.dismiss()
        }
    }
}
#endif

#Preview {
    NavigationStack {
        AboutAppView()
            .environmentObject(AppTheme.shared)
    }
}
