//
//  LocalizationUtil.swift
//  damus
//
//  Created by Terry Yiu on 2/24/23.
//

import Foundation

func bundleForLocale(locale: Locale?) -> Bundle {
    if locale == nil {
        return Bundle.main
    }

    let path = Bundle.main.path(forResource: locale!.identifier, ofType: "lproj")
    return path != nil ? (Bundle(path: path!) ?? Bundle.main) : Bundle.main
}

func localizedStringFormat(key: String, locale: Locale?) -> String {
    let bundle = bundleForLocale(locale: locale)
    let fallback = bundleForLocale(locale: Locale(identifier: "en-US")).localizedString(forKey: key, value: nil, table: nil)
    return bundle.localizedString(forKey: key, value: fallback, table: nil)
}
