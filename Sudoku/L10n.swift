import Foundation

enum L10n {
    static func text(_ key: String) -> String {
        let localized = NSLocalizedString(key, tableName: "Localizable", bundle: .main, value: key, comment: "")
        guard localized == key else { return localized }
        return FrenchTextFallback.polish(key)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale.current, arguments: arguments)
    }
}

private enum FrenchTextFallback {
    static func polish(_ text: String) -> String {
        var result = text

        let exactReplacements = [
            "A regarder": "À regarder",
            "A propos": "À propos",
            "Pourquoi c'est force": "Pourquoi c'est forcé",
            "a gauche": "à gauche",
            "a droite": "à droite",
            "a poser": "à poser",
            "a retirer": "à retirer"
        ]

        if let exact = exactReplacements[text] {
            return exact
        }

        let replacements: [(String, String)] = [
            ("deja ete", "déjà été"),
            ("a ete", "a été"),
            ("deja", "déjà"),
            ("Apres", "Après"),
            ("apres", "après"),
            ("hypothese", "hypothèse"),
            ("testee", "testée"),
            ("resolues", "résolues"),
            ("speciale", "spéciale"),
            ("incoherent", "incohérent"),
            ("a été ignore", "a été ignoré"),
            ("a ete ignore", "a été ignoré"),
            ("proteger", "protéger"),
            ("verifie", "vérifié"),
            ("selectionnee", "sélectionnée"),
            ("demandee", "demandée"),
            ("chiffre demande", "chiffre demandé"),
            ("complete", "complète"),
            ("presents", "présents"),
            ("Repere", "Repère"),
            ("quatrieme", "quatrième"),
            ("marquee", "marquée"),
            ("marquees", "marquées"),
            ("marque", "marqué"),
            ("grises", "grisées"),
            ("affiche", "affiché"),
            ("justifie", "justifié"),
            ("legal", "légal"),
            ("eliminee", "éliminée"),
            ("elimines", "éliminés"),
            ("elimine", "éliminé"),
            ("eliminations", "éliminations"),
            ("bloquees", "bloquées"),
            ("bloques", "bloqués"),
            ("bloquee", "bloquée"),
            ("bloque", "bloqué"),
            ("poses", "posés"),
            ("reservees", "réservées"),
            ("reserves", "réservés"),
            ("reserve", "réservé"),
            ("caches", "cachés"),
            ("cache", "caché"),
            ("comparees", "comparées"),
            ("reliees", "reliées"),
            ("liees", "liées"),
            ("limitees a", "limitées à"),
            ("limites a", "limités à"),
            ("limitees", "limitées"),
            ("limites", "limités"),
            ("differentes", "différentes"),
            ("differente", "différente"),
            ("alignees", "alignées"),
            ("alignes", "alignés"),
            ("opposees", "opposées"),
            ("opposes", "opposés"),
            ("colorees", "colorées"),
            ("colore", "coloré"),
            ("representent", "représentent"),
            ("reseau", "réseau"),
            ("cree", "crée"),
            ("etats", "états"),
            ("scenarios", "scénarios"),
            ("suffisent a", "suffisent à"),
            ("jusqu'a", "jusqu'à"),
            ("a l'interieur", "à l'intérieur"),
            ("a l'autre", "à l'autre"),
            ("a etre", "à être"),
            ("l'etre", "l'être"),
            ("uniquement ou", "uniquement où"),
            (" ou le ", " où le "),
            ("a deux", "à deux"),
            ("a trois", "à trois"),
            ("a quatre", "à quatre"),
            ("a la meme", "à la même"),
            ("dans la meme", "dans la même"),
            ("le meme", "le même"),
            ("la meme", "la même"),
            ("les memes", "les mêmes"),
            ("deux memes", "deux mêmes"),
            ("meme", "même"),
            ("unite", "unité"),
            ("unites", "unités"),
            ("carres", "carrés"),
            ("carre", "carré"),
            ("chaine", "chaîne"),
            ("chaines", "chaînes"),
            ("alternee", "alternée"),
            ("extremites", "extrémités"),
            ("extremite", "extrémité"),
            ("decale", "décalé"),
            ("decales", "décalés"),
            ("cote", "côté"),
            ("cotes", "côtés"),
            ("etre", "être"),
            ("apparaitre", "apparaître"),
            ("facon", "façon"),
            ("facons", "façons"),
            ("sure", "sûre"),
            ("coince", "coincé"),
            ("termine", "terminé"),
            ("derniere", "dernière"),
            ("rectangle ferme", "rectangle fermé"),
            ("filet est ferme", "filet est fermé"),
            ("presque ferme", "presque fermé"),
            ("parfaitement ferme", "parfaitement fermé"),
            ("interieur", "intérieur"),
            ("necessaire", "nécessaire"),
            ("prouvee", "prouvée"),
            ("prouve", "prouvé"),
            ("preuve", "preuve"),
            ("forcée", "forcée"),
            ("forcee", "forcée"),
            ("forces", "forcés"),
            ("est force", "est forcé"),
            ("candidat elimine", "candidat éliminé"),
            ("candidat reserve", "candidat réservé"),
            ("set cache", "set caché"),
            ("points de depart", "points de départ"),
            ("de depart", "de départ"),
            ("c'est", "c'est"),
            (": ", " : ")
        ]

        for (target, replacement) in replacements {
            result = result.replacingOccurrences(of: target, with: replacement)
        }

        return result
    }
}
