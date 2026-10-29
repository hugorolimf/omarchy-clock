.pragma library

// Texts of the clock: written in Portuguese, English for every other locale.
var english = Qt.locale().name.indexOf("pt") !== 0
var en = {
 "Voltar para hoje": "Back to today",
 "NASCIMENTO": "BORN",
 "ATÉ OS": "LIVE TO",
 "VIDA": "LIFE",
 "ano": "year",
 "% de ": "% of ",
 " já passou · dois cliques para o Memento Mori": " gone · double-click for Memento Mori",
 " de ": " of ",
 " anos · dois cliques para esconder": " years · double-click to hide",
 "Coluna S = número da semana · clique para começar a semana em ": "Column W = week number · click to start weeks on ",
 "Mês anterior  [": "Previous month  [",
 "Próximo mês  ]": "Next month  ]",
 "Hoje": "Today",
 "Voltar para hoje  (T)": "Back to today  (T)",
 "S": "W"
}

function T(s) { return english && en[s] !== undefined ? en[s] : s }
