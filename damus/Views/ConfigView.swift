//
//  ConfigView.swift
//  damus
//
//  Created by William Casarin on 2022-06-09.
//
import AVFoundation
import SwiftUI

struct ConfigView: View {
    let state: DamusState
    @Environment(\.dismiss) var dismiss
    @State var show_add_relay: Bool = false
    @State var confirm_logout: Bool = false
    @State var new_relay: String = ""
    @State var show_privkey: Bool = false
    @State var privkey: String
    @State var privkey_copied: Bool = false
    @State var pubkey_copied: Bool = false
    
    @AppStorage("safer_nostr_enabled") var safer_nostr_enabled: Bool = false
    @AppStorage("safer_nostr_url") var safer_nostr_url: String = ""
    @AppStorage("safer_nostr_pass") var safer_nostr_pass: String = ""
    
    @State var tmp_safer_nostr_enabled: Bool = false
    @State var tmp_safer_nostr_url: String = "http://localhost:8080"
    @State var tmp_safer_nostr_pass: String = ""
    @State var tmp_safer_nostr_checking: Bool = false
    @State var tmp_safer_nostr_error: Bool = false
    
    @State var relays: [RelayDescriptor]
    
    let generator = UIImpactFeedbackGenerator(style: .light)
    
    init(state: DamusState) {
        self.state = state
        _privkey = State(initialValue: self.state.keypair.privkey_bech32 ?? "")
        _relays = State(initialValue: state.pool.descriptors)
    }
    
    // TODO: (jb55) could be more general but not gonna worry about it atm
    func CopyButton(is_pk: Bool) -> some View {
        return Button(action: {
            UIPasteboard.general.string = is_pk ? self.state.keypair.pubkey_bech32 : self.privkey
            self.privkey_copied = !is_pk
            self.pubkey_copied = is_pk
            generator.impactOccurred()
        }) {
            let copied = is_pk ? self.pubkey_copied : self.privkey_copied
            Image(systemName: copied ? "checkmark.circle" : "doc.on.doc")
        }
    }
    
    var recommended: [RelayDescriptor] {
        let rs: [RelayDescriptor] = []
        return BOOTSTRAP_RELAYS.reduce(into: rs) { (xs, x) in
            if let _ = state.pool.get_relay(x) {
            } else {
                xs.append(RelayDescriptor(url: URL(string: x)!, info: .rw))
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            Form {
                Section("Relays") {
                    List(Array(relays), id: \.url) { relay in
                        RelayView(state: state, relay: relay.url.absoluteString)
                    }
                }
                
                Section("Recommended Relays") {
                    List(recommended, id: \.url) { r in
                        RecommendedRelayView(damus: state, relay: r.url.absoluteString)
                    }
                }
                
                Section("Public Account ID") {
                    HStack {
                        Text(state.keypair.pubkey_bech32)
                        
                        CopyButton(is_pk: true)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                
                if let sec = state.keypair.privkey_bech32 {
                    Section("Secret Account Login Key") {
                        HStack {
                            if show_privkey == false {
                                SecureField("PrivateKey", text: $privkey)
                                    .disabled(true)
                            } else {
                                Text(sec)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                            
                            CopyButton(is_pk: false)
                        }
                        
                        Toggle("Show", isOn: $show_privkey)
                    }
                }
                
                Section("Safer Nostr Delegation") {
                    TextField("Instance URL (https://delegation.damus.io)", text: $tmp_safer_nostr_url)
                        .disabled(tmp_safer_nostr_checking)
                    SecureField("Instance pass if pass is enabled", text: $tmp_safer_nostr_pass)
                        .disabled(tmp_safer_nostr_checking)
                    
                    
                    Toggle("Enable", isOn: $tmp_safer_nostr_enabled)
                        .disabled(tmp_safer_nostr_checking)
                        .onChange(of: tmp_safer_nostr_enabled) { newValue in
                            if !newValue {
                                safer_nostr_enabled = false
                            } else {
                                tmp_safer_nostr_checking = true
                                
                                // Check
                                let r = SNFetch(instance_url: tmp_safer_nostr_url + "/is_good", instance_password: tmp_safer_nostr_pass, variables: [:])
                                
                                let r2 = SNCheckStatus.parse(r ?? "")
                                
                                // 0 Is error | 1 Is success
                                if r2?.code == 1 {
                                    safer_nostr_url = tmp_safer_nostr_url
                                    safer_nostr_pass = tmp_safer_nostr_pass
                                    tmp_safer_nostr_checking = false
                                    safer_nostr_enabled = true
                                } else {
                                    tmp_safer_nostr_error = true
                                }
                            }
                        }
                }.onAppear {
                    tmp_safer_nostr_url = safer_nostr_url
                    tmp_safer_nostr_pass = safer_nostr_pass
                    tmp_safer_nostr_enabled = safer_nostr_enabled
                }
                
                Section("Reset") {
                    Button("Logout") {
                        confirm_logout = true
                    }
                }
            }
            
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: { show_add_relay = true }) {
                        Label("", systemImage: "plus")
                            .foregroundColor(.accentColor)
                            .padding()
                    }
                }
                
                Spacer()
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .alert("Error: Safer Nostr Instance", isPresented: $tmp_safer_nostr_error) {
            Button("OK") {
                tmp_safer_nostr_enabled = false
                tmp_safer_nostr_checking = false
                tmp_safer_nostr_error = false
            }
        } message: {
            Text("Make sure that the URL and password provided for your instance are correct, or that your instance is running")
        }
        .alert("Logout", isPresented: $confirm_logout) {
            Button("Cancel") {
                confirm_logout = false
            }
            Button("Logout") {
                notify(.logout, ())
            }
        } message: {
            Text("Make sure your nsec account key is saved before you logout or you will lose access to this account")
        }
        .sheet(isPresented: $show_add_relay) {
            AddRelayView(show_add_relay: $show_add_relay, relay: $new_relay) { m_relay in
                guard let relay = m_relay else {
                    return
                }
                
                guard let url = URL(string: relay) else {
                    return
                }
                
                guard let ev = state.contacts.event else {
                    return
                }
                
                guard let privkey = state.keypair.privkey else {
                    return
                }
                
                let info = RelayInfo.rw
                
                guard (try? state.pool.add_relay(url, info: info)) != nil else {
                    return
                }
                
                state.pool.connect(to: [new_relay])
                
                guard let new_ev = add_relay(ev: ev, privkey: privkey, current_relays: state.pool.descriptors, relay: new_relay, info: info) else {
                    return
                }
                
                process_contact_event(pool: state.pool, contacts: state.contacts, pubkey: state.pubkey, ev: ev)
                
                state.pool.send(.event(new_ev))
            }
        }
        .onReceive(handle_notify(.switched_timeline)) { _ in
            dismiss()
        }
        .onReceive(handle_notify(.relays_changed)) { _ in
            self.relays = state.pool.descriptors
        }
    }
}

struct ConfigView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ConfigView(state: test_damus_state())
        }
    }
}
