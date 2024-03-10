
### Načtení všech zdrojových dat a spojení do jednoho souboru pro každý typ hlášení.
###
### src https://opendata.sukl.cz/?q=katalog-otevrenych-dat, DIS-13, LEK-13, REG-13, ZAH-13
### typ = lek/dis/reg/zah/erecept


## inicializace

library('openxlsx');
options(scipen = 999);


## načtení souborů

nactiData <- function(typ) {
  
  # všechny soubory v adresáři
  soubory <- list.files(paste0('../data/src/', typ));
  soubory <- soubory[-1];
  
  # inicializace
  separator <- ';';
  decimal <- ',';

  df <- read.csv(paste0('../data/src/', typ, '/', soubory[1]), header = T, sep = separator, dec = decimal, encoding = 'Windows-1250');
  df <- df[-1:-nrow(df),];
  
  # sesypot na hromadu
  for(i in soubory) {
    temp <- read.csv(paste0('../data/src/', typ, '/', i), header = T, sep = separator, dec = decimal, encoding = 'Windows-1250');
    df <- rbind(df, temp);
  }
  
  return(df);

} 


## dočištění dat, otypování a doplnění součtů

vycistiData <- function(data, typ) {

  df <- data;
  
  # otypování a přejmenování
  colnames(df) <- gsub('Počet.balení.M', 'Počet.balení', colnames(df));
  
  # doplnění vlastních sloupců
  df$ATC1 <- substr(df$ATC7, 1, 1);
  df$ATC3 <- substr(df$ATC7, 1, 3);
  df['Název.ATC'] <- do.call('paste', df[,c(5, 3)]);
  df['Název.ATC'] <- apply(format(df[, c(5, 3)]), 1, paste, collapse = '_');
  df['Název.doplněk.ATC'] <- do.call('paste', df[,c(5, 6, 3)]);
  df['Název.doplněk.ATC'] <- apply(format(df[, c(5, 6, 3)]), 1, paste, collapse = '_');
  if(typ == 'reg') {
    df['DDD.celkem'] <- apply(df[, c(10, 11)], 1, prod);
  }
  if(typ == 'dis') {
    df['DDD.celkem'] <- apply(df[, c(10, 12)], 1, prod);
    df['Cena.celkem'] <- apply(df[, c(10, 11)], 1, prod);
  }
  if(typ == 'lek') {
    df['DDD.celkem'] <- apply(df[, c(9, 12)], 1, prod);
    df['Nákupní.cena.celkem'] <- apply(df[, c(9, 10)], 1, prod);
    df['Prodejní.cena.celkem'] <- apply(df[, c(9, 11)], 1, prod);
  }
  if(typ == 'zah') {
    df['DDD.celkem'] <- apply(df[, c(10, 12)], 1, prod);
    df['Cena.celkem'] <- apply(df[, c(10, 11)], 1, prod);
  }

  # selekce sloupců
  if(typ == 'reg') {
    df <- df[, c(1, 2, 9, 12, 4, 3, 15, 14, 5, 6, 16, 17, 13, 7, 8, 10, 11, 18)];
  }
  if (typ == 'dis') {
    df <- df[, c(1, 2, 9, 13, 4, 3, 16, 15, 5, 6, 17, 18, 7, 8, 14, 10, 12, 19, 11, 20)];  
  }
  if (typ == 'lek') {
    df <- df[, c(1, 2, 13, 4, 3, 16, 15, 5, 6, 17, 18, 7, 8, 14, 9, 12, 19, 10, 11, 20, 21)];
  }
  if (typ == 'zah') {
    df <- df[, c(1, 2, 9, 4, 3, 16, 15, 5, 6, 17, 18, 7, 8, 13, 14, 10, 12, 19, 11, 20)];
  }  
  
  return(df);
  
}


## uložení dat do xlsx

ulozData <- function(data, adr, jemno) {  
  
  write.xlsx(data, paste0('../data/', adr, '/', jemno, '.xlsx'));

}



### Analytické fce.

## pro každé ID léku spočítá z REG, DIS, LEK a ZAH měsíční sumy počtu balení, pohyby léků rozeznává podle sloupců Typ.hlášení a Typ.odběratele
## id: ID léku
## start, end: datum ve formátu YYYY.MM
## jenpredpis: pokud TRUE, počítá jen léky na předpis, vč. léků na předpis s omezením (tj. Způsob.výdeje == R, C, L)

spojLekPodleID <- function(id, start, end, jenpredpis) {

  start <- as.Date(paste0(start, '.01'), '%Y.%m.%d');
  end <- as.Date(paste0(end, '.01'), '%Y.%m.%d');

# vytvoření prázdného data framu pro výstup.
# pokud jenpredpis == TRUE, načte připravené datasety léků s -r, jinak bez něj
# pokud nenajde ID léku v prvním datasetu, hledá v ostatních
  if(jenpredpis) {
    df <- dfregr[dfregr$Kód.SÚKL == id,];
    if(nrow(df) == 0) { df <- dfdisr[dfdisr$Kód.SÚKL == id,]; }
    if(nrow(df) == 0) { df <- dflekr[dflekr$Kód.SÚKL == id,]; }
    if(nrow(df) == 0) { df <- dfzah[dfzah$Kód.SÚKL == id,]; }
  } else {
    df <- dfreg[dfreg$Kód.SÚKL == id,];
    if(nrow(df) == 0) { df <- dfdis[dfdis$Kód.SÚKL == id,]; }
    if(nrow(df) == 0) { df <- dflek[dflek$Kód.SÚKL == id,]; }
    if(nrow(df) == 0) { df <- dfzah[dfzah$Kód.SÚKL == id,]; }
  }

# omezení na relevantní sloupce
  df <- data.frame(df$Kód.SÚKL, df$Název.přípravku, df$Doplněk.názvu, df$ATC7)
  colnames(df) <- c('Kód.SÚKL', 'Název.přípravku', 'Doplněk.názvu', 'ATC7');
  df <- df[1,];

# REG

# příprava datasetu a omezení na datum mezi start a end
  if(jenpredpis) {
    reg <- dfregr[dfregr$Kód.SÚKL == id,];
  } else {
    reg <- dfreg[dfreg$Kód.SÚKL == id,];
  }
  if(nrow(reg) > 0) {
    reg$Období <- as.Date(paste0(reg$Období, '.01'), '%Y.%m.%d');
    reg <- reg[reg$Období >= start & reg$Období <= end,];
  }

# připojení k df
  regdis <- reg[reg$Typ.hlášení == 'Distributor',];
  df$REG.distributor <- sum(regdis$Počet.balení);
  regoov <- reg[reg$Typ.hlášení == 'OOV',];
  df$REG.OOV <- sum(regoov$Počet.balení);

# DIS

# příprava datasetu a omezení na datum mezi start a end
  if(jenpredpis) {
    dis <- dfdisr[dfdisr$Kód.SÚKL == id,];
  } else {
    dis <- dfdis[dfdis$Kód.SÚKL == id,];
  }
  if(nrow(dis) > 0) {
    dis$Období <- as.Date(paste0(dis$Období, '.01'), '%Y.%m.%d');
    dis <- dis[dis$Období >= start & dis$Období <= end,];
  }

# připojení k df
  dislek <- dis[dis$Typ.odběratele == 'LEKARNA',];
  df$DIS.lékárna <- sum(dislek$Počet.balení);
  dislekar <- dis[dis$Typ.odběratele == 'LEKAR',];
  df$DIS.lékař <- sum(dislekar$Počet.balení);
  disveterinar <- dis[dis$Typ.odběratele == 'VETERINARNI_LEKAR',];
  df$DIS.veterinář <- sum(disveterinar$Počet.balení);
  disdiscr <- dis[dis$Typ.odběratele == 'DISTRIBUTOR_CR',];
  df$DIS.distributor.ČR <- sum(disdiscr$Počet.balení);
  disdiszah <- dis[dis$Typ.odběratele %in% c('DISTRIBUTOR_EU', 'DISTRIBUTOR_MIMO_EU'),];
  df$DIS.distributor.zahraničí <- sum(disdiszah$Počet.balení);
  diszah <- dis[dis$Typ.odběratele == 'ZAHRANICI',];
  df$DIS.OOV.zahraničí <- sum(diszah$Počet.balení);
  disost <- dis[dis$Typ.odběratele %in% c('HYGIENICKA_STANICE', 'NUKLEARNI_MEDICINA',
            'OBCHODNI_ZASTUPCE', 'OSOBA_POSKYTUJICI_ZDRAVOTNI_PECI', 'PRODEJCE_VLP',
            'TRANSFUZNI_SLUZBA'),];
  df$DIS.ostatní <- sum(disost$Počet.balení);

# LEK

# příprava datasetu a omezení na datum mezi start a end
  if(jenpredpis) {
    lek <- dflekr[dflekr$Kód.SÚKL == id,];
  } else {
    lek <- dflek[dflek$Kód.SÚKL == id,];
  }
  if(nrow(lek) > 0) {
    lek$Období <- as.Date(paste0(lek$Období, '.01'), '%Y.%m.%d');
    lek <- lek[lek$Období >= start & lek$Období <= end,];
  }

# připojení k df
  lekrecept <- lek[lek$Typ.hlášení == 'recept',];
  df$LEK.recept <- sum(lekrecept$Počet.balení);
  lekzadanka <- lek[lek$Typ.hlášení == 'žádanka',];
  df$LEK.žádanka <- sum(lekzadanka$Počet.balení);
  lekvolny <- lek[lek$Typ.hlášení == 'volný',];
  df$LEK.volný <- sum(lekvolny$Počet.balení);

# ZAH
# pozor, neukazuje Způsob.výdeje, takže nejdou omezit na receptové!
# pozor, ostatní datasety začínají 2020.05, ZAH až 2022.01!

# příprava datasetu a omezení na datum mezi start a end
  zah <- dfzah[dfzah$Kód.SÚKL == id,];
  if(nrow(zah) > 0) {
    zah$Období <- as.Date(paste0(zah$Období, '.01'), '%Y.%m.%d');
    zah <- zah[zah$Období >= start & zah$Období <= end,];
  }

# připojení k df
  zahdis <- zah[zah$Typ.odběratele %in% c('DISTRIBUTOR_EU', 'DISTRIBUTOR_MIMO_EU'),];
  df$ZAH.distributor <- sum(zahdis$Počet.balení);
  zahoov <- zah[zah$Typ.odběratele == 'OOV',];
  df$ZAH.OOV <- sum(zahoov$Počet.balení);

  return(df);

}


## vyhledání všech ID pro název léku ve všech datasetech a sesypání do jedné tabulky

spojLekPodleNazvu <- function(nazev, start, end, jenpredpis) {

  if(jenpredpis) {
    ids <- c(dfregr[dfregr$Název.přípravku == nazev,]$Kód.SÚKL,
             dfdisr[dfdisr$Název.přípravku == nazev,]$Kód.SÚKL,
             dflekr[dflekr$Název.přípravku == nazev,]$Kód.SÚKL,
             dfzah[dfzah$Název.přípravku == nazev,]$Kód.SÚKL);
  } else {
    ids <- c(dfreg[dfreg$Název.přípravku == nazev,]$Kód.SÚKL,
             dfdis[dfdis$Název.přípravku == nazev,]$Kód.SÚKL,
             dflek[dflek$Název.přípravku == nazev,]$Kód.SÚKL,
             dfzah[dfzah$Název.přípravku == nazev,]$Kód.SÚKL);
  }
  ids <- unique(ids);

# inicializace výstupu na prvním ID
  df <- spojLekPodleID(ids[1], start, end, jenpredpis);

# pokud je lék spojený s víc ID, přidá všechny verze
  if(length(ids) > 1) {
    for(i in 2:length(ids)) {
      df <- rbind(df, spojLekPodleID(ids[i], start, end, jenpredpis));
    }
  }

  return(df);

}


## pro daný lék (všechny jeho varianty) spočítá detailní toky měsíc po měsíci

spocitejMesice <- function(nazev, start, end, jenpredpis) {

  start <- as.Date(paste0(start, '.01'), '%Y.%m.%d');
  end <- as.Date(paste0(end, '.01'), '%Y.%m.%d');

  mesice <- seq(start, end, by = 'month');
  mesice <- format(mesice, '%Y.%m')

# inicializace tabulky prvním měsícem
  df <- spojLekPodleNazvu(nazev, mesice[1], mesice[1], jenpredpis);
  sumy <- colSums(df[, 5:18], na.rm = T, dims = 1);
  df$Doplněk.názvu <- paste(unique(df$Doplněk.názvu), collapse = ', ');

  df <- df[1, 1:4];
  df <- data.frame(df, t(sumy));
  df$Měsíc <- mesice[1];

# doplnění dalších měsíců
  if(length(mesice) > 1) {

    for(i in 2:length(mesice)) {

      dfmes <- spojLekPodleNazvu(nazev, mesice[i], mesice[i], jenpredpis);
      sumy <- colSums(dfmes[, 5:18], na.rm = T, dims = 1);
      df$Doplněk.názvu <- paste(unique(df$Doplněk.názvu), collapse = ', ');

      dfmes <- df[1, 1:4];
      dfmes <- data.frame(dfmes, t(sumy));
      dfmes$Měsíc <- mesice[i];

      df <- rbind(df, dfmes);

    }

  }

# názvů léku může být víc (pro každé ID jiný), do df je doplnit všechny
  df$Název.přípravku <- unique(paste(unique(df$Název.přípravku), collapse = ', '));

  return(df);

}


## spočítá pro všechny léky základní toky (REG -> DIS, DIS -> LEK a LEK -> OUT) a legální reexport (DIS -> ZAH vs. ZAH)

spocitejToky <- function(data) {

  df <- data;

# dodávky výrobce/držitele licence distributorům
  df$REGDIS <- df$REG.distributor;
# dodávky distributorů do lékáren
  df$DISLEK <- df$DIS.lékárna;
# výdeje z lékáren
  df$LEKOUT <- df$LEK.recept + df$LEK.žádanka;

# dodávky distributorů do zahraničí
  df$DISZAH <- df$DIS.distributor.zahraničí + df$DIS.OOV.zahraničí
# legální reeexport
  df$ZAHZAH <- df$ZAH.distributor + df$ZAH.OOV

# očekávané zásoby v distribuci
  df$Chybí.distributor <- df$REGDIS - df$DISLEK;
# očekávané zásoby v lékárnách
  df$Chybí.lékárny <- df$DISLEK - df$LEKOUT;
# zahraniční reexport, rozdíl mezi hlášením DIS a ZAH
  df$Rozdíl.reexport <- df$DISZAH - df$ZAHZAH;
# vydané recepty a vydané žádanky
  df$REC <- df$LEK.recept;
  df$ZAD <- df$LEK.žádanka;

  df <- df[, c(1:4, 19:ncol(df))];

  return(df);

}


## vytvoří seznam všech názvů léků v datasetu; podle něj se následně spočítá celkový přehled toků

vytvorSeznamLeku <- function(jenpredpis) {

  if(jenpredpis) {
    df <- c(dfregr$Název.přípravku, dfdisr$Název.přípravku, dflekr$Název.přípravku,
            dfzah$Název.přípravku);
  } else {
    df <- c(dfreg$Název.přípravku, dfdis$Název.přípravku, dflek$Název.přípravku,
            dfzah$Název.přípravku);
  }
  df <- unique(df);
  df <- df[order(df)];

  return(df);

}


## pro seznam názvů léků spočítá základní toky
## seznam: seznam léků, které probere
## scukni: pokud TRUE, všechny varianty léku spojit pod jeho hlavní název

analyzujSeznamLeku <- function(seznam, start, end, jenpredpis, scukni) {

# inicializace: analýza prvního léku seznamu
  df <- spocitejToky(spojLekPodleNazvu(seznam[1], start, end, jenpredpis));

# doplnění ostatních léků
  if(length(seznam) > 1) {
    for(i in 2:length(seznam)) {
      df <- rbind(df, spocitejToky(spojLekPodleNazvu(seznam[i], start, end, jenpredpis)));
    }
  }

  if(scukni) {
    df <- aggregate(cbind(REGDIS, DISLEK, LEKOUT, DISZAH, ZAHZAH, Chybí.distributor,
                          Chybí.lékárny, Rozdíl.reexport, REC, ZAD) ~ Název.přípravku + ATC7,
                    data = df, FUN = sum);
  }

# dopočítat procenta
  df$Chybí.distributor.proc <- round(100 * df$Chybí.distributor/df$REGDIS, 1);
  df$Chybí.lékárny.proc <- round(100 * df$Chybí.lékárny/df$DISLEK, 1);
  df$Rozdíl.reexport.proc <- round(100 * df$Rozdíl.reexport/df$DISZAH, 1);

# dopočítat poměr receptových a žádankových výdejů
  df$REC.proc <- round(100 * df$REC/(df$REC + df$ZAD), 1);

  return(df);

}



### Vizuální analýza konkrétních léků


## dodávky, receptové a žádankové výdeje po měsíci
## k ověření výpadků

grafPoMesici <- function(lek, start, end, jenpredpis) {

  df <- spocitejMesice(lek, start, end, jenpredpis);
  plot(df$DIS.lékárna, type = 'l', col = 'darkred', xlab = 'měsíc', ylab = 'balení', main = lek, ylim = c(0, max(df$DIS.lékárna, df$LEK.recept, df$LEK.žádanka)));
  lines(df$LEK.recept, type = 'l', col = 'darkblue');
  lines(df$LEK.žádanka, type = 'l', col = 'lightblue');

}


## rozdíl mezi dodávkami a výdejemi u všech balení léku

grafPodleBaleni <- function(lek, start, end, jenpredpis, scukni) {

  df <- analyzujSeznamLeku(lek, start, end, jenpredpis, scukni);
  df1 <- data.frame(df$DISLEK);
  df1 <- cbind(df1, df$LEKOUT);
  barplot(t(df1), beside = T, main = lek, ylab = 'balení', names = df$Doplněk.názvu);

}


## průměrná cena konkrétního balení léku (nákupní, prodejní) v posledních šesti měsících (zajímá mě aktuální, ne historická)
## jen receptové

spocitejCenu <- function(lek, baleni) {

  df <- dflekr[dflekr$Název.přípravku == lek & dflekr$Doplněk.názvu == baleni,];
  print(mean(df$Nákupní.cena.bez.DPH[(nrow(temp)-12):nrow(temp)], na.rm = T));
  print(mean(df$Konečná.prodejní.cena.s.DPH[(nrow(temp)-12):nrow(temp)], na.rm = T));

}



################################################################################

# agregace měsíčních hlášení ze SÚKL do megatabulek
dfreg <- nactiData('reg');
dfdis <- nactiData('dis');
dflek <- nactiData('lek');
dfzah <- nactiData('zah');

# dočištění
dfreg <- vycistiData(dfreg, 'reg');
dfdis <- vycistiData(dfdis, 'dis');
dflek <- vycistiData(dflek, 'lek');
dfzah <- vycistiData(dfzah, 'zah');

# megatabulky jen pro léky na předpis
dfregr <- dfreg[dfreg$Způsob.výdeje %in% c('R', 'C', 'L'),];
dfdisr <- dfdis[dfdis$Způsob.výdeje %in% c('R', 'C', 'L'),];
dflekr <- dflek[dflek$Způsob.výdeje %in% c('R', 'C', 'L'),];

# uložení megatabulek
ulozData(dfreg, 'out', 'reg');
ulozData(dfdis, 'out', 'dis');
ulozData(dflek, 'out', 'lek');
ulozData(dfzah, 'out', 'zah');

ulozData(dfregr, 'out', 'regr');
ulozData(dfdisr, 'out', 'disr');
ulozData(dflekr, 'out', 'lekr');

# seznam všech léků ve všech hlášeních
seznamLeku <- vytvorSeznamLeku(jenpredpis = F);
seznamLekur <- vytvorSeznamLeku(jenpredpis = T);

# gigatabulky s analýzou hlavních toků pro všechny léky (scuknuté i full, receptové i komplet varianty)
dfbigrscuk <- analyzujSeznamLeku(seznamLekur, start = '2020.05', end = '2023.12', jenpredpis = T, scukni = T);
dfbigr <- analyzujSeznamLeku(seznamLekur, start = '2020.05', end = '2023.12', jenpredpis = T, scukni = F);
dfbigscuk <- analyzujSeznamLeku(seznamLeku, start = '2020.05', end = '2023.12', jenpredpis = F, scukni = T);
dfbig <- analyzujSeznamLeku(seznamLeku, start = '2020.05', end = '2023.12', jenpredpis = F, scukni = F);

# uložení gigatabulek
ulozData(dfbigrscuk, 'ana', 'bigrscuk');
ulozData(dfbigr, 'ana', 'bigr');
ulozData(dfbigscuk, 'ana', 'bigscuk');
ulozData(dfbig, 'ana', 'big');

# výběr léků podezřelých z reexportu: víc než 100k balení do lékáren, víc než 30 % ztracených
podezreli <- dfbigrscuk;
podezreli <- podezreli[((podezreli$DISLEK > 100000) & (podezreli$Chybí.lékárny.proc > 30)),];
podezreli <- podezreli[order(podezreli$Chybí.lékárny.proc, decreasing = T),];
