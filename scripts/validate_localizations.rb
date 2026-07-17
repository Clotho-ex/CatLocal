#!/usr/bin/env ruby

require "json"

catalog_path = ARGV.fetch(0, File.expand_path("../CatLocal/Resources/Localizable.xcstrings", __dir__))
raw_catalog = File.read(catalog_path)
catalog = JSON.parse(raw_catalog)
strings = catalog.fetch("strings")

supported_locales = %w[en tr]
translation_locales = supported_locales.drop(1)
plural_categories = {
  "en" => %w[one other],
  "tr" => %w[other]
}
plural_keys = [
  "%lld cats",
  "%lld cats saved locally",
  "%lld places",
  "%lld places typed by you.",
  "%lld saved cards",
  "%lld cards selected",
  "%lld styles",
  "Delete %lld Cards",
  "%lld more cats",
  "%lld cats found",
  "Photo with %lld cats marked by number",
  "Shows %lld styles",
  "%lld families"
]
obsolete_keys = [
  "%@ cats", "%@ cats saved locally", "%@ in %@ families", "%1$@ in %2$@ families", "%1$lld in %2$lld families", "%@ more %@",
  "%@ places", "%@ places typed by you.", "%@ saved", "%@ selected", "%@ styles",
  "1 cat", "1 cat saved locally", "1 place", "1 place typed by you.", "1 saved", "1 selected",
  "Delete %@ Cards", "Delete 1 Card", "Step %@ of %@", "Cat %@", "Marked %@ in the photo",
  "Camera or private photo", "Lift On Device", "On-device lift", "Lifted cutout",
  "Lifting the subject", "Lifting...", "Looking for cats, then lifting the subject",
  "Your furry encounters are safe", "No Account No Cloud", "Ready for Your First Local",
  "Meet Your First Local", "First Local", "Local Card",
  "Capture an encounter and turn it into a local card.", "Saved to Home", "Try exact center",
  "No Note Yet.", "Adding a little finish", "A private field journal for local encounters.", "Yours",
  "Your first card keeps the lifted cutout, design, notes, and typed place together.",
  "Edit before saving", "On This iPhone", "Preparing Cat Card", "Storage used",
  "Changes the app language immediately.", "English", "Ελληνικά", "Hrvatski", "Language",
  "Polski", "Română", "System Language", "Türkçe", "Українська",
  "Use Turkish", "Switch CatLocal back to Turkish."
]
commented_keys = [
  "Home", "Choose private photo", "Memory Place", "Card details", "Edit Before Saving", "On this iPhone",
  "On this iPhone, by design", "Cat cutout", "%lld families", "%1$lld in %2$@",
  "Use English", "Use System Language"
]
canonical_keys = ["Edit Before Saving", "On this iPhone", "Preparing cat card"]
preserved_keys = [
  "Saved to Collection", "Collectible Card", "Meet Your First Cat",
  "Ready for Your First Cat", "On-device cutout", "Cat cutout",
  "Removing background...", "Finds the cat and removes the background",
  "Your cat encounters stay private", "No Account. No Cloud.", "No note yet.",
  "Take a photo or choose one", "Try the center"
]
reviewed_direct_values = {
  ["Built Without", "tr"] => "İçermediklerimiz",
  ["A New Cat", "tr"] => "Yeni Bir Kedi",
  ["About CatLocal", "tr"] => "CatLocal Hakkında",
  ["Add a Memory Place to build Catlas.", "tr"] => "Catlas'ı oluşturmak için bir anı konumu ekleyin.",
  ["App Information", "tr"] => "Uygulama Bilgileri",
  ["Capture or Import", "tr"] => "Çek veya İçe Aktar",
  ["Card Motion", "tr"] => "Kart Hareketi",
  ["Delete All", "tr"] => "Tümünü Sil",
  ["Delete All Cats", "tr"] => "Tüm Kedileri Sil",
  ["Delete Cat", "tr"] => "Kediyi Sil",
  ["Double-tap to try the center of the photo. Use Retake or Choose private photo if the cat is elsewhere.", "tr"] => "Fotoğrafın ortasını denemek için çift dokunun. Kedi başka yerdeyse yeniden çek veya özel fotoğraf seç seçeneklerini kullanın.",
  ["Haptic Feedback", "tr"] => "Dokunsal Geri Bildirim",
  ["Home", "tr"] => "Ana Sayfa",
  ["Home opens next. Tap Camera when you meet a cat, or choose a private photo.", "tr"] => "Sırada Ana Sayfa var. Bir kediyle karşılaştığınızda Kamera'ya dokunun veya özel bir fotoğraf seçin.",
  ["Image Storage", "tr"] => "Görsel Depolama",
  ["Journal Entry", "tr"] => "Günlük Kaydı",
  ["Local Storage", "tr"] => "Yerel Depolama",
  ["Location Data Stripped", "tr"] => "Konum Verileri Kaldırılır",
  ["Make It Yours", "tr"] => "Kendinize Göre Yapın",
  ["Memory Place", "tr"] => "Anı Konumu",
  ["Memory Place, %1$@", "tr"] => "Anı konumu: %1$@",
  ["Memory Place, %1$@, %2$@", "tr"] => "Anı konumu: %1$@, %2$@",
  ["New Cat", "tr"] => "Yeni Kedi",
  ["Nickname", "tr"] => "Takma Ad",
  ["No Memory Place yet.", "tr"] => "Henüz anı konumu yok.",
  ["Open Home", "tr"] => "Ana Sayfayı Aç",
  ["Open Settings", "tr"] => "Ayarları Aç",
  ["Place Detail", "tr"] => "Konum Ayrıntısı",
  ["Privacy & About", "tr"] => "Gizlilik ve Hakkında",
  ["Privacy Receipt", "tr"] => "Gizlilik Özeti",
  ["Save to Collection", "tr"] => "Koleksiyona Kaydet",
  ["Skip to Home", "tr"] => "Atla ve Ana Sayfaya Git",
  ["Use English", "tr"] => "İngilizce Kullan",
  ["Use System Language", "tr"] => "Sistem Dilini Kullan",
  ["Welcome to CatLocal", "tr"] => "CatLocal'a Hoş Geldiniz",
  ["iOS Reduce Motion always takes priority over Card Motion.", "tr"] => "iOS Hareketi Azalt ayarı her zaman Kart Hareketi ayarına göre önceliklidir."
}
reviewed_plural_values = {}

failures = []
failures << "sourceLanguage must be en" unless catalog["sourceLanguage"] == "en"
failures << "catalog must use version 1.0" unless catalog["version"] == "1.0"

top_level_key_lines = raw_catalog.lines.count { |line| line.match?(/^    ".+": \{$/) }
failures << "duplicate or malformed top-level keys" unless top_level_key_lines == strings.length

strings.each do |key, entry|
  failures << "#{key.inspect} is unintentionally stale" if entry["extractionState"] == "stale"

  localizations = entry.fetch("localizations", {})
  missing = translation_locales - localizations.keys
  extra = localizations.keys - supported_locales
  failures << "#{key.inspect} missing locales: #{missing.join(", ")}" unless missing.empty?
  failures << "#{key.inspect} has unintended locales: #{extra.join(", ")}" unless extra.empty?

  localizations.each do |locale, localization|
    direct_value = localization.dig("stringUnit", "value")
    failures << "#{key.inspect} #{locale} has an empty value" if direct_value == ""

    plural = localization.dig("variations", "plural")
    next unless plural

    expected_categories = plural_categories.fetch(locale)
    actual_categories = plural.keys
    failures << "#{key.inspect} #{locale} plural categories #{actual_categories.inspect}, expected #{expected_categories.inspect}" unless actual_categories.sort == expected_categories.sort
    plural.each do |category, variant|
      value = variant.dig("stringUnit", "value")
      failures << "#{key.inspect} #{locale}.#{category} is empty" if value.nil? || value.empty?
      failures << "#{key.inspect} #{locale}.#{category} must contain exactly one %lld" unless value&.scan("%lld")&.length == 1
    end
  end

  next if entry.dig("localizations", "en", "variations", "plural")

  source_placeholders = key.scan(/%(?:\d+\$)?(?:@|lld|ld|d|f|s)/)
  localizations.each do |locale, localization|
    value = localization.dig("stringUnit", "value")
    next unless value

    translated_placeholders = value.scan(/%(?:\d+\$)?(?:@|lld|ld|d|f|s)/)
    source_types = source_placeholders.map { |placeholder| placeholder.sub(/%\d+\$/, "%") }.sort
    translated_types = translated_placeholders.map { |placeholder| placeholder.sub(/%\d+\$/, "%") }.sort
    failures << "#{key.inspect} #{locale} placeholder types do not match" unless source_types == translated_types

    if source_placeholders.length > 1
      failures << "#{key.inspect} must use positional placeholders" unless source_placeholders.all? { |placeholder| placeholder.match?(/^%\d+\$/) }
      failures << "#{key.inspect} #{locale} must use positional placeholders" unless translated_placeholders.all? { |placeholder| placeholder.match?(/^%\d+\$/) }
    end
  end
end

plural_keys.each { |key| failures << "missing plural key #{key.inspect}" unless strings.key?(key) }

obsolete_keys.each { |key| failures << "obsolete key remains: #{key.inspect}" if strings.key?(key) }
canonical_keys.each { |key| failures << "missing canonical key #{key.inspect}" unless strings.key?(key) }
preserved_keys.each { |key| failures << "previously corrected key is missing: #{key.inspect}" unless strings.key?(key) }
commented_keys.each do |key|
  failures << "#{key.inspect} needs a translator comment" if strings.dig(key, "comment").to_s.strip.empty?
end

reviewed_direct_values.each do |(key, locale), expected|
  actual = strings.dig(key, "localizations", locale, "stringUnit", "value")
  failures << "#{key.inspect} #{locale} is #{actual.inspect}, expected #{expected.inspect}" unless actual == expected
end

reviewed_plural_values.each do |(key, locale, category), expected|
  actual = strings.dig(key, "localizations", locale, "variations", "plural", category, "stringUnit", "value")
  failures << "#{key.inspect} #{locale}.#{category} is #{actual.inspect}, expected #{expected.inspect}" unless actual == expected
end

app_source_files = Dir[File.expand_path("../CatLocal/**/*.swift", __dir__)]
app_sources = app_source_files.to_h { |path| [path, File.read(path)] }
strings.each do |key, entry|
  next unless entry["extractionState"] == "manual"

  quoted_key = JSON.generate(key)
  next if app_sources.any? { |_path, source| source.include?(quoted_key) }

  failures << "manual key has no exact app source call site: #{key.inspect}"
end

privacy_key = "Sanitized originals, cutouts, and thumbnails stay in CatLocal's private app container. Their folders use iOS file protection until the first unlock after restart, are excluded from backups, and are removed with their cat."
privacy_fragments = {
  "tr" => ["özel uygulama kapsayıcısında", "yeniden başlatmanın ardından ilk kilit", "yedeklemelere dahil edilmez", "kediyle birlikte silinir"]
}
privacy_fragments.each do |locale, fragments|
  value = strings.dig(privacy_key, "localizations", locale, "stringUnit", "value").to_s
  fragments.each { |fragment| failures << "privacy copy #{locale} lost #{fragment.inspect}" unless value.include?(fragment) }
end

gps_key = "Typed labels only. No GPS is requested."
gps_access_terms = {
  "tr" => "GPS erişimi istemez"
}
gps_access_terms.each do |locale, fragment|
  value = strings.dig(gps_key, "localizations", locale, "stringUnit", "value").to_s
  failures << "GPS copy #{locale} does not explicitly describe access requests" unless value.include?(fragment)
end

if failures.empty?
  puts "Localization catalog valid: #{strings.length} keys, #{supported_locales.length} languages, #{plural_keys.length} plural entries, 0 stale entries."
else
  warn failures.map { |failure| "- #{failure}" }.join("\n")
  exit 1
end
