# App Store listing — localizations (for the version after 2.0.0)

Paste-ready metadata for six more App Store localizations. **Nothing here has
been submitted.** Drafted 2026-11-22 by Claude, not by native speakers: have
each one read by someone fluent before it goes in. Wrong keywords waste the
field, and a clumsy description costs conversions in exactly the market it was
meant to win.

Why: the listing is English only (iTunes lookup, 2026-11-22:
`languageCodesISO2A: ["EN"]`). Every localization adds its own subtitle and
100-character keyword field, which are what App Store search indexes, and its
own description for the people who land there. BetterDisplay ships its app in
38 languages; this only localizes the *listing*.

Rules these follow:

- **They describe the next version, not 2.0.0**: Extra Dim is free, the Pro
  trial is 14 days, there are Shortcuts actions, ten more tools (27 in all,
  14 free) and a Menu Layout option, and Window Snapping is gone from the App
  Store build. A localization is added to an editable version in App Store
  Connect, so it goes in with that build. The counts follow
  `docs/app-store-listing.md`.
- **No prices.** Apple shows localized prices on the listing itself, and a
  hard-coded `$9.99` is wrong in every one of these storefronts. The
  description still names both purchases, the 14-day trial, the auto-renewal
  terms and which features are Pro — the substance of the 2.3.2 and 3.1.2
  rejections.
- **Each says the app is in English.** The app ships English only; saying so
  up front is cheaper than a one-star review that says it.
- Tool names that appear in the app's English menu (Extra Dim, Warmth, and
  the newer tools such as Focus, File Shelf and App Volume) are kept in
  English, or added in brackets, so the listing maps onto the menu.
- The descriptions cover permissions only through the English listing and
  /privacy; they do not have the English "Privacy and permissions" section.
- Keywords leave out words already in the name and subtitle, as in the English
  listing. App Store Connect counts characters, not bytes;
  `python3 scripts/check-listing-lengths.py docs/app-store-listing-localized.md`
  checks every field.

Name stays **MaxCandela** in every locale. Support, marketing and privacy URLs
are the English ones.

---

## Japanese (ja)

### Subtitle

```
メニューバーツール & XDR輝度ブースト
```

### Keywords

```
スクリーンショット,クリップボード,履歴,スリープ防止,ポモドーロ,文字認識,OCR,QRコード,Bluetooth,音量,カレンダー,カラーピッカー,タイマー,明るさ,HDR,減光,色温度,世界時計
```

### Promotional text

```
27のMacツールをメニューバーのアイコンひとつに。うち14は無料です。Proでは注釈付きスクリーンショット、クリップボードマネージャ、アプリごとの音量調整、XDR輝度ブーストが使えます。
```

### Description

```
MaxCandelaは、27のMacツールをメニューバーのアイコンひとつにまとめたアプリです。うち14は無料で、期限なく使えます。

無料
• スリープ防止 — 30分、数時間、またはオフにするまで画面をスリープさせません。
• タイマーとフォーカス(Focus) — カウントダウン、または25/5・50/10・90/20分の作業と休憩のサイクル。残り時間をメニューバーに表示します。
• 休憩リマインダー(Breaks) — 画面を20〜60分使うごとに、20秒間遠くを見るよう知らせます。入力中のアプリからフォーカスを奪いません。
• クリップボードツール — 大文字・小文字の変換、行の並べ替え、URL・Base64、JSON整形、SHA-256など。
• スクラッチパッド(Scratchpad) — 入力するそばから保存される、浮かぶメモ。
• カラーピッカー、ジェネレーター(UUID・パスワード・QRコード)、世界時計、月表示のカレンダー、サウンドの入出力切り替え、システム情報。
• デスクトップ(Desktop) — デスクトップのアイコンを隠し、ノッチを黒いメニューバーの帯に溶け込ませます。
• Extra Dim — 明るさキーの最小値よりさらに暗く。すべてのMacで使えます。

PRO
• スクリーンショット(Screenshot) — 範囲・ウインドウ・画面全体を撮り、矢印、四角形、テキスト、ハイライト、モザイク、黒塗り、切り抜きで注釈を付けられます。
• 画面上の文字のコピーとQRコードの読み取り(Mac上で認識し、送信しません)。
• クリップボードマネージャ(200件・検索・ピン留め)、ファイルシェルフ(File Shelf:画像の変換とリサイズ、PDFの結合)。
• アプリごとの音量(App Volume:0〜200%)、Bluetoothデバイスのワンクリック接続、背景のウインドウを暗くする機能(Dim Background Windows)。
• メニューバーアイコンの非表示(macOS 26以前)、ショートカットの実行、次の会議とカレンダーの予定。
• XDR輝度ブースト — Liquid Retina XDRディスプレイ搭載のMacBook Pro 14/16インチ、またはPro Display XDRで、macOSが通常のコンテンツに設けている輝度の上限を超えて画面全体を明るくします。色はキャリブレーションどおりに保たれ、ディスプレイが熱を持つと自動で抑えます。
• 暖色(Warmth) — 白を暖かい色味に。終日または夜間のみ。
• ショートカットApp、Spotlight、Siriからブーストのオン・オフを操作できます。

対応するMac
macOS 15.6以降(メニューバーアイコンの非表示はmacOS 26以前のみ)。輝度ブーストにはHDRの余裕(ヘッドルーム)があるディスプレイが必要で、MacBook Air、iMac、一般的な外部ディスプレイにはありません。購入前に、無料体験でお使いのMacで動作することをご確認ください。

料金
ダウンロード無料。Proは初回ダウンロード日から14日間無料で試せます。その後は買い切り(Lifetime)または月額サブスクリプション(Monthly)を選べます。月額サブスクリプションは、App Storeのアカウント設定で解約するまで毎月自動更新されます。1回の購入で、同じApple AccountのすべてのMacで使えます。

アプリの表示は英語です。

利用規約(EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
プライバシーポリシー: https://maxcandela.com/privacy/
```

### What's New in This Version

```
• 新しい無料ツール:フォーカス(作業と休憩のサイクル)、休憩リマインダー、スクラッチパッド、月表示のカレンダー、デスクトップ(アイコンとノッチを隠す)、ジェネレーターのQRコード。
• 新しいProツール:注釈付きスクリーンショット、画面上のQRコードの読み取り、ファイルシェルフ、アプリごとの音量、Bluetoothのワンクリック接続、背景のウインドウを暗くする機能、カレンダーの予定表示。
• Options > Menu Layoutで、ツールをひとつのリストに並べるか、5つの短いグループにまとめるかを選べます。
• ショートカットApp、Spotlight、Siriから輝度ブーストをオン・オフ・切り替えできるようになりました。maxcandela://boost/on などのリンクにも対応しています。
• Extra Dimがすべてのユーザーに無料になりました。
• Proの無料体験が14日間になりました。
• ウインドウの整列(Window Snapping)は削除しました。Mac App Storeのアプリは、ほかのアプリのウインドウを動かせないためです。
```

---

## German (de-DE)

### Subtitle

```
Menüleisten-Tools & XDR-Boost
```

### Keywords

```
bildschirmfoto,zwischenablage,wach,pomodoro,texterkennung,ocr,bluetooth,lautstärke,helligkeit,hdr
```

### Promotional text

```
27 Mac-Tools unter einem Menüleisten-Symbol, 14 davon gratis. Pro: Bildschirmfotos mit Markierungen, Zwischenablage-Manager, Lautstärke pro App und XDR-Helligkeitsboost.
```

### Description

```
MaxCandela bündelt 27 Mac-Tools unter einem einzigen Symbol in der Menüleiste. 14 davon sind dauerhaft kostenlos.

KOSTENLOS
• Wach bleiben — der Bildschirm geht nicht in den Ruhezustand: 30 Minuten, einige Stunden oder bis Sie es ausschalten.
• Timer und Fokus (Focus) — ein Countdown oder Arbeits- und Pausenzyklen von 25/5, 50/10 oder 90/20 Minuten, direkt in der Menüleiste.
• Pausen (Breaks) — nach 20 bis 60 Minuten Bildschirmzeit die Erinnerung, 20 Sekunden in die Ferne zu schauen. Sie nimmt der App, in der Sie tippen, nie den Fokus.
• Zwischenablage-Werkzeuge — Groß-/Kleinschreibung, Zeilen sortieren, URL und Base64, JSON formatieren, SHA-256 und mehr.
• Notizzettel (Scratchpad) — ein schwebendes Notizfenster, das beim Tippen speichert.
• Farbwähler, Generator (UUID, Passwort, QR-Code), Weltzeituhr, Monatskalender, Audio-Ein- und -Ausgabe wechseln, Systeminfos.
• Schreibtisch (Desktop) — Schreibtischsymbole ausblenden und die Notch in einem schwarzen Menüleistenstreifen verschwinden lassen.
• Extra Dim — dunkler, als die Helligkeitstasten erlauben. Auf jedem Mac.

PRO
• Bildschirmfoto (Screenshot) — Bereich, Fenster oder ganzen Bildschirm aufnehmen und mit Pfeilen, Rechtecken, Text, Textmarker, Verpixeln, Schwärzen und Zuschneiden bearbeiten.
• Text und QR-Codes vom Bildschirm kopieren (Erkennung auf dem Mac, kein Upload).
• Zwischenablage-Manager (200 Einträge, Suche, Anheften), Dateiablage (File Shelf: Bilder umwandeln und verkleinern, PDFs zusammenführen).
• Lautstärke pro App (App Volume, 0–200 %), Bluetooth-Geräte mit einem Klick verbinden, Hintergrundfenster abdunkeln.
• Menüleisten-Symbole ausblenden (bis macOS 26), Kurzbefehle ausführen, nächstes Meeting und Termine im Kalender.
• XDR-Helligkeitsboost — auf einem MacBook Pro 14″ oder 16″ mit Liquid Retina XDR Display oder einem Pro Display XDR wird der ganze Bildschirm heller, als macOS es für normale Inhalte zulässt. Farbtreu, und er nimmt sich zurück, wenn das Display warm wird.
• Wärme (Warmth) — ein wärmeres Weiß, den ganzen Tag oder nur nachts.
• Den Boost per Kurzbefehle-App, Spotlight oder Siri ein- und ausschalten.

WELCHE MACS
macOS 15.6 oder neuer (Menüleisten-Symbole ausblenden nur bis macOS 26). Der Helligkeitsboost braucht ein Display mit HDR-Reserve; MacBook Air, iMac und gewöhnliche externe Monitore haben keine. Bitte prüfen Sie im kostenlosen Testzeitraum, ob der Boost auf Ihrem Mac funktioniert.

PREISE
Kostenloser Download. Pro ist ab dem ersten Download 14 Tage kostenlos, danach als Einmalkauf (Lifetime) oder Monatsabo (Monthly). Das Abo verlängert sich jeden Monat automatisch, bis Sie es in den Einstellungen Ihres App Store-Accounts kündigen. Ein Kauf gilt für alle Macs mit Ihrem Apple Account.

Die App ist auf Englisch.

Nutzungsbedingungen (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Datenschutzerklärung: https://maxcandela.com/privacy/
```

### What's New in This Version

```
• Neue kostenlose Tools: Fokus (Arbeits- und Pausenzyklen), Pausen-Erinnerung, Notizzettel, Monatskalender, Schreibtisch (Symbole und Notch ausblenden) und QR-Codes im Generator.
• Neue Pro-Tools: Bildschirmfoto mit Markierungen, QR-Codes vom Bildschirm scannen, Dateiablage, Lautstärke pro App, Bluetooth mit einem Klick, Hintergrundfenster abdunkeln und Termine im Kalender.
• Options > Menu Layout: alle Tools in einer Liste oder in fünf kurzen Gruppen.
• Kurzbefehle-Aktionen: den Helligkeitsboost per Kurzbefehle-App, Spotlight oder Siri ein-, aus- oder umschalten – oder mit Links wie maxcandela://boost/on.
• Extra Dim ist jetzt für alle kostenlos.
• Die kostenlose Pro-Testphase dauert jetzt 14 Tage.
• „Fenster einrasten“ (Window Snapping) wurde entfernt: Apps aus dem Mac App Store dürfen keine Fenster anderer Apps bewegen.
```

---

## French (fr-FR)

### Subtitle

```
Outils de menu & boost XDR
```

### Keywords

```
capture,écran,presse-papiers,veille,pomodoro,ocr,bluetooth,volume,luminosité,hdr,assombrir
```

### Promotional text

```
27 outils Mac sous une icône de la barre des menus, dont 14 gratuits. Pro ajoute captures d’écran annotées, gestionnaire de presse-papiers, volume par app et boost XDR.
```

### Description

```
MaxCandela réunit 27 outils Mac sous une seule icône de la barre des menus. 14 sont gratuits, sans limite de durée.

GRATUIT
• Rester éveillé — empêche l’écran de se mettre en veille : 30 minutes, quelques heures ou jusqu’à ce que vous l’arrêtiez.
• Minuteur et Focus — un compte à rebours, ou des cycles de travail et de pause de 25/5, 50/10 ou 90/20 minutes, affichés dans la barre des menus.
• Pauses (Breaks) — après 20 à 60 minutes d’écran, un rappel de regarder au loin pendant 20 secondes, sans jamais prendre le focus à l’app où vous tapez.
• Outils de presse-papiers — majuscules/minuscules, tri des lignes, URL et Base64, mise en forme JSON, SHA-256 et plus.
• Bloc-notes (Scratchpad) — une fenêtre de notes flottante, enregistrée au fil de la frappe.
• Pipette à couleurs, générateur (UUID, mot de passe, QR code), horloge mondiale, calendrier du mois, choix de l’entrée et de la sortie audio, infos système.
• Bureau (Desktop) — masque les icônes du bureau et fond l’encoche dans une bande noire de la barre des menus.
• Extra Dim — plus sombre que ne le permettent les touches de luminosité. Sur tous les Mac.

PRO
• Capture d’écran (Screenshot) — d’une zone, d’une fenêtre ou de tout l’écran, puis annotations : flèches, rectangles, texte, surligneur, pixellisation, masquage, recadrage.
• Copie du texte et lecture des QR codes affichés à l’écran (reconnus sur votre Mac, jamais envoyés).
• Gestionnaire de presse-papiers (200 éléments, recherche, épingles), étagère à fichiers (File Shelf : conversion et redimensionnement d’images, fusion de PDF).
• Volume par app (App Volume, 0–200 %), connexion Bluetooth en un clic, assombrissement des fenêtres d’arrière-plan.
• Masquer des icônes de la barre des menus (macOS 26 et antérieur), lancement de Raccourcis, prochaine réunion et événements dans le calendrier.
• Boost de luminosité XDR — sur un MacBook Pro 14″ ou 16″ avec écran Liquid Retina XDR, ou un Pro Display XDR, rend tout l’écran plus lumineux que la limite imposée par macOS aux contenus ordinaires. Couleurs fidèles, et il se modère quand l’écran chauffe.
• Chaleur (Warmth) — un blanc plus chaud, toute la journée ou seulement la nuit.
• Activez ou coupez le boost depuis l’app Raccourcis, Spotlight ou Siri.

QUELS MAC
macOS 15.6 ou ultérieur (masquer des icônes de la barre des menus : macOS 26 et antérieur uniquement). Le boost exige un écran disposant d’une marge HDR : MacBook Air, iMac et écrans externes ordinaires n’en ont pas. Vérifiez pendant l’essai gratuit que le boost fonctionne sur votre Mac avant d’acheter.

TARIFS
Téléchargement gratuit. Pro est gratuit pendant 14 jours à compter du premier téléchargement, puis en achat unique (Lifetime) ou en abonnement mensuel (Monthly), renouvelé automatiquement chaque mois jusqu’à sa résiliation dans les réglages de votre compte App Store. Un achat couvre tous les Mac associés à votre compte Apple.

L’app est en anglais.

Conditions d’utilisation (EULA) : https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Confidentialité : https://maxcandela.com/privacy/
```

### What's New in This Version

```
• Nouveaux outils gratuits : Focus (cycles travail/pause), rappels de pause, bloc-notes, calendrier du mois, Bureau (masquer les icônes et l’encoche) et QR codes dans le générateur.
• Nouveaux outils Pro : capture d’écran annotée, lecture des QR codes à l’écran, étagère à fichiers, volume par app, Bluetooth en un clic, assombrissement des fenêtres d’arrière-plan et événements dans le calendrier.
• Options > Menu Layout : tous les outils dans une seule liste, ou en cinq groupes courts.
• Actions Raccourcis : activez, coupez ou basculez le boost de luminosité depuis l’app Raccourcis, Spotlight ou Siri, ou avec des liens comme maxcandela://boost/on.
• Extra Dim est désormais gratuit pour tous.
• L’essai gratuit de Pro dure désormais 14 jours.
• L’ancrage des fenêtres (Window Snapping) a été retiré : les apps du Mac App Store ne peuvent pas déplacer les fenêtres d’autres apps.
```

---

## Korean (ko)

### Subtitle

```
메뉴 막대 도구 & XDR 밝기 부스트
```

### Keywords

```
스크린샷,클립보드,기록,잠자기방지,뽀모도로,텍스트인식,OCR,QR코드,블루투스,음량,캘린더,컬러피커,타이머,화면밝기,HDR,어둡게,세계시계,색온도,메뉴바
```

### Promotional text

```
Mac 도구 27가지를 메뉴 막대 아이콘 하나에. 14가지는 무료입니다. Pro에서는 주석 스크린샷, 클립보드 관리자, 앱별 음량 조절, XDR 밝기 부스트를 쓸 수 있습니다.
```

### Description

```
MaxCandela는 Mac 도구 27가지를 메뉴 막대 아이콘 하나에 모았습니다. 그중 14가지는 기간 제한 없이 무료입니다.

무료
• 잠자기 방지 — 30분, 몇 시간, 또는 직접 끌 때까지 화면이 꺼지지 않게 합니다.
• 타이머와 집중(Focus) — 카운트다운, 또는 25/5·50/10·90/20분 작업·휴식 주기. 남은 시간이 메뉴 막대에 표시됩니다.
• 휴식 알림(Breaks) — 화면을 20~60분 쓸 때마다 20초 동안 먼 곳을 보라고 알려 줍니다. 입력 중인 앱의 포커스를 빼앗지 않습니다.
• 클립보드 도구 — 대소문자 변환, 줄 정렬, URL·Base64, JSON 정리, SHA-256 등.
• 메모장(Scratchpad) — 입력하는 대로 저장되는 떠 있는 메모 창.
• 컬러 피커, 생성기(UUID·비밀번호·QR 코드), 세계 시계, 월간 달력, 사운드 입출력 전환, 시스템 정보.
• 데스크탑(Desktop) — 바탕화면 아이콘을 숨기고, 노치를 검은 메뉴 막대 띠로 가립니다.
• Extra Dim — 밝기 키의 최저 단계보다 더 어둡게. 모든 Mac에서 작동합니다.

PRO
• 스크린샷(Screenshot) — 영역·창·전체 화면을 캡처하고 화살표, 사각형, 텍스트, 형광펜, 모자이크, 검게 가리기, 자르기로 주석을 답니다.
• 화면 속 텍스트 복사와 QR 코드 읽기(Mac에서 인식하며 업로드하지 않음).
• 클립보드 관리자(200개·검색·고정), 파일 선반(File Shelf: 이미지 변환·크기 조절, PDF 합치기).
• 앱별 음량(App Volume, 0~200%), 블루투스 기기 원클릭 연결, 뒤쪽 창 어둡게 하기.
• 메뉴 막대 아이콘 숨기기(macOS 26 이하), 단축어 실행, 다음 회의와 달력의 일정.
• XDR 밝기 부스트 — Liquid Retina XDR 디스플레이를 갖춘 14·16형 MacBook Pro 또는 Pro Display XDR에서, macOS가 일반 콘텐츠에 두는 밝기 한도보다 화면 전체를 더 밝게 합니다. 색은 정확하게 유지되고, 디스플레이가 뜨거워지면 스스로 낮춥니다.
• 따뜻한 색(Warmth) — 하루 종일 또는 밤에만 더 따뜻한 흰색으로.
• 단축어 앱, Spotlight, Siri로 부스트를 켜고 끌 수 있습니다.

지원 Mac
macOS 15.6 이상(메뉴 막대 아이콘 숨기기는 macOS 26 이하에서만). 밝기 부스트에는 HDR 여유(헤드룸)가 있는 디스플레이가 필요하며, MacBook Air, iMac, 일반 외장 모니터에는 없습니다. 구매 전에 무료 체험 기간 동안 내 Mac에서 작동하는지 확인해 주세요.

가격
무료 다운로드. Pro는 처음 다운로드한 날부터 14일간 무료로 체험할 수 있고, 이후 한 번 구매(Lifetime) 또는 월간 구독(Monthly)을 선택할 수 있습니다. 구독은 App Store 계정 설정에서 해지할 때까지 매월 자동 갱신됩니다. 한 번 구매로 같은 Apple 계정의 모든 Mac에서 사용할 수 있습니다.

앱은 영어로 제공됩니다.

이용 약관(EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
개인정보 처리방침: https://maxcandela.com/privacy/
```

### What's New in This Version

```
• 새 무료 도구: 집중(작업·휴식 주기), 휴식 알림, 메모장, 월간 달력, 데스크탑(아이콘·노치 숨기기), 생성기의 QR 코드.
• 새 Pro 도구: 주석 스크린샷, 화면 속 QR 코드 읽기, 파일 선반, 앱별 음량, 블루투스 원클릭 연결, 뒤쪽 창 어둡게 하기, 달력의 일정 표시.
• Options > Menu Layout: 모든 도구를 한 목록에 두거나 짧은 그룹 다섯 개로 묶을 수 있습니다.
• 단축어 동작: 단축어 앱, Spotlight, Siri에서 밝기 부스트를 켜고, 끄고, 전환할 수 있습니다. maxcandela://boost/on 같은 링크도 지원합니다.
• 이제 Extra Dim을 누구나 무료로 쓸 수 있습니다.
• Pro 무료 체험이 14일로 늘었습니다.
• 창 정렬(Window Snapping)은 제거되었습니다. Mac App Store 앱은 다른 앱의 창을 움직일 수 없기 때문입니다.
```

---

## Simplified Chinese (zh-Hans)

### Subtitle

```
菜单栏工具箱与 XDR 亮度增强
```

### Keywords

```
截图,剪贴板,历史,防休眠,番茄钟,文字识别,OCR,二维码,蓝牙,音量,日历,取色器,计时器,屏幕亮度,HDR,调暗,色温,世界时钟,密码生成
```

### Promotional text

```
27 款 Mac 工具集中在菜单栏的一个图标里，其中 14 款免费。Pro 版提供带标注的截图、剪贴板管理器、按 App 调节音量和 XDR 亮度增强。
```

### Description

```
MaxCandela 把 27 款 Mac 工具放进菜单栏的一个图标里，其中 14 款永久免费。

免费
• 防休眠 —— 让屏幕保持唤醒 30 分钟、几个小时，或直到你关闭。
• 计时器与专注（Focus）—— 倒计时，或 25/5、50/10、90/20 分钟的工作与休息循环，剩余时间显示在菜单栏。
• 休息提醒（Breaks）—— 每使用屏幕 20 到 60 分钟，提醒你远眺 20 秒，不会抢走你正在输入的 App 的焦点。
• 剪贴板工具 —— 大小写转换、按行排序、URL 与 Base64、JSON 格式化、SHA-256 等。
• 便笺（Scratchpad）—— 浮动的笔记窗口，边输入边保存。
• 取色器、生成器（UUID、密码、二维码）、世界时钟、月历、声音输入输出切换、系统信息。
• 桌面（Desktop）—— 隐藏桌面图标，并用黑色的菜单栏条带让刘海融为一体。
• Extra Dim —— 比亮度键的最低档更暗，所有 Mac 均可使用。

PRO
• 截图（Screenshot）—— 截取区域、窗口或整个屏幕，再用箭头、矩形、文字、荧光笔、马赛克、涂黑和裁剪进行标注。
• 复制屏幕上的文字、识别屏幕上的二维码（在 Mac 本地识别，不上传）。
• 剪贴板管理器（200 条、搜索、置顶）、文件架（File Shelf：转换和缩放图片、合并 PDF）。
• 按 App 调节音量（App Volume，0–200%）、一键连接蓝牙设备、调暗后台窗口。
• 隐藏菜单栏图标（macOS 26 及更早版本）、运行快捷指令、下一个会议和月历中的日程。
• XDR 亮度增强 —— 在配备 Liquid Retina XDR 显示屏的 14 英寸或 16 英寸 MacBook Pro，或 Pro Display XDR 上，让整个屏幕超过 macOS 为日常内容设定的亮度上限。色彩保持准确，显示屏变热时会自动回落。
• 暖色（Warmth）—— 全天或仅在夜间使用更暖的白色。
• 可通过“快捷指令”App、Spotlight 或 Siri 开关亮度增强。

适用的 Mac
macOS 15.6 或更高版本（隐藏菜单栏图标仅支持 macOS 26 及更早版本）。亮度增强需要具备 HDR 余量的显示屏；MacBook Air、iMac 和普通外接显示器没有。购买前请在免费试用期内确认它在你的 Mac 上有效。

价格
免费下载。Pro 自首次下载之日起可免费试用 14 天，之后可选择一次性买断（Lifetime）或按月订阅（Monthly）。订阅每月自动续订，直到你在 App Store 账户设置中取消。一次购买，即可用于登录同一 Apple 账户的所有 Mac。

App 界面为英文。

使用条款（EULA）：https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
隐私政策：https://maxcandela.com/privacy/
```

### What's New in This Version

```
• 新增免费工具：专注（工作与休息循环）、休息提醒、便笺、月历、桌面（隐藏图标和刘海），以及生成器中的二维码。
• 新增 Pro 工具：带标注的截图、识别屏幕上的二维码、文件架、按 App 调节音量、一键连接蓝牙、调暗后台窗口，以及月历中的日程。
• Options > Menu Layout：可以把所有工具放在一个列表里，或分成五个简短的分组。
• 快捷指令操作：可在“快捷指令”App、Spotlight 或 Siri 中打开、关闭或切换亮度增强，也支持 maxcandela://boost/on 等链接。
• Extra Dim 现已对所有人免费。
• Pro 免费试用延长至 14 天。
• 已移除窗口吸附（Window Snapping）：Mac App Store 中的 App 不能移动其他 App 的窗口。
```

---

## Spanish (Mexico) (es-MX)

### Subtitle

```
Herramientas y brillo XDR
```

### Keywords

```
captura,portapapeles,despierto,pomodoro,ocr,bluetooth,volumen,calendario,cuentagotas,hdr,atenuar
```

### Promotional text

```
27 herramientas para Mac en un solo icono de la barra de menús, 14 gratis. Pro añade capturas con anotaciones, gestor del portapapeles, volumen por app y brillo XDR.
```

### Description

```
MaxCandela reúne 27 herramientas para Mac bajo un solo icono de la barra de menús. 14 son gratis, sin límite de tiempo.

GRATIS
• Mantener despierto — evita que la pantalla entre en reposo: 30 minutos, unas horas o hasta que lo apagues.
• Temporizador y Focus — una cuenta regresiva, o ciclos de trabajo y descanso de 25/5, 50/10 o 90/20 minutos, en la barra de menús.
• Descansos (Breaks) — tras 20 a 60 minutos frente a la pantalla, un aviso para mirar a lo lejos durante 20 segundos, sin quitarle el foco a la app en la que escribes.
• Herramientas del portapapeles — mayúsculas y minúsculas, ordenar líneas, URL y Base64, formatear JSON, SHA-256 y más.
• Bloc de notas (Scratchpad) — una ventana flotante de notas que se guarda mientras escribes.
• Selector de color, generador (UUID, contraseña, código QR), reloj mundial, calendario del mes, cambio de entrada y salida de audio, información del sistema.
• Escritorio (Desktop) — oculta los iconos del escritorio y disimula el notch con una franja negra en la barra de menús.
• Extra Dim — más oscuro de lo que permiten las teclas de brillo. En cualquier Mac.

PRO
• Captura de pantalla (Screenshot) — de una zona, una ventana o toda la pantalla, con anotaciones: flechas, rectángulos, texto, resaltador, pixelado, bloque negro y recorte.
• Copiar texto y leer códigos QR de la pantalla (se reconocen en tu Mac y nunca se suben).
• Gestor del portapapeles (200 elementos, búsqueda, fijados), estante de archivos (File Shelf: convierte y redimensiona imágenes, une PDF).
• Volumen por app (App Volume, 0–200 %), conexión Bluetooth en un clic, atenuar las ventanas del fondo.
• Ocultar iconos de la barra de menús (macOS 26 y anteriores), ejecutar Atajos, próxima reunión y eventos en el calendario.
• Aumento de brillo XDR — en una MacBook Pro de 14″ o 16″ con pantalla Liquid Retina XDR, o en un Pro Display XDR, ilumina toda la pantalla por encima del límite que macOS impone al contenido cotidiano. Colores fieles, y se modera solo cuando la pantalla se calienta.
• Calidez (Warmth) — un blanco más cálido, todo el día o solo de noche.
• Enciende o apaga el aumento desde la app Atajos, Spotlight o Siri.

QUÉ MAC
macOS 15.6 o posterior (ocultar iconos de la barra de menús: solo macOS 26 y anteriores). El aumento de brillo necesita una pantalla con margen HDR; MacBook Air, iMac y los monitores externos comunes no lo tienen. Comprueba durante la prueba gratuita que funcione en tu Mac antes de comprar.

PRECIOS
Descarga gratuita. Pro es gratis durante 14 días desde la primera descarga; después, compra única (Lifetime) o suscripción mensual (Monthly), que se renueva automáticamente cada mes hasta que la canceles en la configuración de tu cuenta de App Store. Una compra sirve para todas las Mac con tu cuenta de Apple.

La app está en inglés.

Términos de uso (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacidad: https://maxcandela.com/privacy/
```

### What's New in This Version

```
• Nuevas herramientas gratis: Focus (ciclos de trabajo y descanso), recordatorios de descanso, bloc de notas, calendario del mes, Escritorio (oculta iconos y el notch) y códigos QR en el generador.
• Nuevas herramientas Pro: capturas con anotaciones, lectura de códigos QR en pantalla, estante de archivos, volumen por app, Bluetooth en un clic, atenuar ventanas del fondo y eventos en el calendario.
• Options > Menu Layout: todas las herramientas en una sola lista o en cinco grupos cortos.
• Acciones de Atajos: enciende, apaga o alterna el aumento de brillo desde la app Atajos, Spotlight o Siri, o con enlaces como maxcandela://boost/on.
• Extra Dim ahora es gratis para todos.
• La prueba gratuita de Pro ahora dura 14 días.
• Se eliminó el ajuste de ventanas (Window Snapping): las apps de la Mac App Store no pueden mover las ventanas de otras apps.
```
