#!/usr/bin/env ruby

require "json"

root = File.expand_path("..", __dir__)
catalog = JSON.parse(File.read(File.join(root, "CatLocal/Resources/Localizable.xcstrings")))
strings = catalog.fetch("strings")

extractable_repaired = [
  "A note about this encounter", "About CatLocal", "App Information", "Built Without",
  "Camera", "Choose private photo", "Close camera", "Could not delete card",
  "Could not update storage", "Delete All Cats", "Drag to catch the light", "Edit",
  "Edit Card", "Home", "Make It Yours", "Memory Place", "Nickname", "OK",
  "Open Settings", "Privacy & About", "Privacy Receipt", "Private scan on this iPhone",
  "Retake", "Save Cat", "Settings", "Sort places", "Sort saved cards", "Stop and return",
  "Take photo", "Try another photo", "Version",
  "Removing the background", "Try the center"
].sort

removed_count_keys = [
  "%@ cats", "%@ cats saved locally", "%@ in %@ families", "%1$@ in %2$@ families",
  "%1$lld in %2$lld families", "%@ more %@", "%@ places", "%@ places typed by you.",
  "%@ saved", "%@ selected", "%@ styles", "1 cat", "1 cat saved locally", "1 place",
  "1 place typed by you.", "1 saved", "1 selected", "Delete %@ Cards", "Delete 1 Card",
  "Step %@ of %@", "Cat %@", "Marked %@ in the photo"
].sort

removed_source_copy = [
  "Camera or private photo", "Lift On Device", "On-device lift", "Lifted cutout",
  "Lifting the subject", "Lifting...", "Looking for cats, then lifting the subject",
  "Your furry encounters are safe", "No Account No Cloud", "Ready for Your First Local",
  "Meet Your First Local", "Local Card", "Capture an encounter and turn it into a local card.",
  "Saved to Home", "Try exact center", "No Note Yet.", "Adding a little finish",
  "A private field journal for local encounters.",
  "Your first card keeps the lifted cutout, design, notes, and typed place together."
].sort

removed_unused = ["First Local", "Storage used", "Yours"]
removed_language_picker = [
  "Changes the app language immediately.", "English", "Ελληνικά", "Hrvatski", "Language",
  "Polski", "Română", "System Language", "Türkçe", "Українська"
].sort
removed_turkish_specific_fallback = [
  "Switch CatLocal back to Turkish.", "Use Turkish"
].sort
consolidated_duplicates = {
  "Edit before saving" => "Edit Before Saving",
  "On This iPhone" => "On this iPhone",
  "Preparing Cat Card" => "Preparing cat card"
}
manual_keys = strings.each_with_object([]) do |(key, entry), keys|
  keys << key if entry["extractionState"] == "manual"
end.sort
accessibility_review_keys = strings.each_with_object([]) do |(key, entry), keys|
  keys << key if entry["comment"].to_s.downcase.include?("accessibility")
end.sort

def key_list(keys)
  keys.map { |key| "- `#{key.gsub("`", "\\`")}`" }.join("\n")
end

source_files = Dir[File.join(root, "CatLocal/**/*.swift")].sort
source_lines = source_files.to_h { |path| [path, File.readlines(path)] }

def source_hits(key, source_lines, root)
  quoted_key = JSON.generate(key)
  source_lines.each_with_object([]) do |(path, lines), hits|
    lines.each_with_index do |line, index|
      next unless line.include?(quoted_key)

      hits << {
        path: path.delete_prefix("#{root}/"),
        line: index + 1,
        source: line.strip,
        context: lines[[index - 3, 0].max..[index + 3, lines.length - 1].min].join
      }
    end
  end
end

manual_records = manual_keys.map do |key|
  entry = strings.fetch(key)
  hits = source_hits(key, source_lines, root)
  raise "manual key has no exact app source call site: #{key.inspect}" if hits.empty?

  purposes = []
  if entry["comment"].to_s.downcase.include?("accessibility") ||
      hits.any? { |hit| hit[:context].include?("accessibility") }
    purposes << "Accessibility"
  end

  if entry.dig("localizations", "en", "variations", "plural") ||
      hits.any? { |hit|
        hit[:source].match?(/catLocalized|CatLocalLocalization|catLocalKey|case .*:|return |title:|detail:|message:|label:|hint:|value:/) ||
          hit[:path].include?("/Localization/")
      }
    purposes << "Dynamic runtime lookup"
  end

  if hits.any? { |hit|
       hit[:source].match?(/Text\(|Label\(|Button\(|Section\(|TextField\(|navigationTitle|\.alert\(/)
     }
    purposes << "Visible UI"
  end

  purposes << "Dynamic runtime lookup" if purposes.empty?
  locations = hits.map { |hit| "`#{hit[:path]}:#{hit[:line]}`" }.join(", ")
  { key: key, purposes: purposes.uniq.join("; "), locations: locations }
end

manual_purpose_counts = manual_records
  .flat_map { |record| record[:purposes].split("; ") }
  .each_with_object(Hash.new(0)) { |purpose, counts| counts[purpose] += 1 }

def markdown_cell(value)
  value.to_s.gsub("|", "\\|").gsub("\n", " ")
end

manual_table = manual_records.map do |record|
  "| `#{markdown_cell(record[:key])}` | #{record[:purposes]} | #{record[:locations]} |"
end.join("\n")

output = <<~MARKDOWN
  # CatLocal Localization Catalog Audit

  Date: 2026-07-17

  This is the repository record for the stale-entry correction required by the localization plan. Regenerate it with `ruby scripts/generate_localization_audit.rb` after intentional catalog changes.

  ## Audit Result

  - Initial catalog: 203 keys, including 144 entries marked stale.
  - Initial stale classification: 34 live compiler-extractable entries, 109 live manual/dynamic entries, and one unused entry.
  - Corrected catalog: #{strings.length} keys, #{manual_keys.length} intentional manual entries, #{strings.length - manual_keys.length} compiler-current entries, 13 plural entries, and zero stale entries.
  - Both supported locales are present: English and Turkish.
  - Every retained manual key has at least one exact app-source call site.
  - Purpose classifications: #{manual_purpose_counts.sort.map { |purpose, count| "#{purpose} #{count}" }.join(", ")}. A key can serve more than one purpose.

  ## Repaired Compiler-Extractable Entries (#{extractable_repaired.length})

  These live source keys were refreshed or migrated to current source copy instead of being deleted as if unused.

  #{key_list(extractable_repaired)}

  ## Removed Superseded Count And Format Keys (#{removed_count_keys.length})

  These were replaced by integer-based String Catalog plural entries or positional placeholders. Keeping them would allow non-plural, preformatted, or non-reorderable formatting to return.

  #{key_list(removed_count_keys)}

  ## Removed Superseded Source Copy (#{removed_source_copy.length})

  These keys were removed only after their English call sites and assertions moved to the approved cat, collectible-card, on-device background-removal, collection, and field-journal language.

  #{key_list(removed_source_copy)}

  ## Final Duplicate Consolidation

  These case-only duplicates were consolidated after every visible and accessibility call site moved to the canonical key.

  #{consolidated_duplicates.map { |removed, canonical| "- `#{removed}` -> `#{canonical}`" }.join("\n")}

  Updated Swift call sites:

  - `CatLocal/Features/Capture/CaptureView.swift:1400` and `:1524`: `Preparing Cat Card` -> `Preparing cat card`.
  - `CatLocal/Features/Capture/CaptureView.swift:1445`: `Edit before saving` -> `Edit Before Saving`.
  - `CatLocal/Features/Settings/SettingsView.swift:370`: `On This iPhone` -> `On this iPhone`.
  - `CatLocalTests/CatLocalCoreTests.swift`: canonical-key coverage and removed-key regression checks.

  ## Removed Unused Standalone Keys (#{removed_unused.length})

  These had no exact runtime call site. `Yours` appeared only as part of `Make It Yours`; neither key was retained or replaced with invented product copy.

  #{key_list(removed_unused)}

  ## Removed Multi-Language Picker Keys (#{removed_language_picker.length})

  These labels belonged only to the retired all-language Settings picker. CatLocal still bundles every supported localization for automatic iOS language selection, while supported non-English configurations see only the English fallback action.

  #{key_list(removed_language_picker)}

  ## Removed Turkish-Specific Fallback Keys (#{removed_turkish_specific_fallback.length})

  These were replaced by the language-neutral `Use System Language` action so every supported non-English locale can return from the English fallback without naming a particular language.

  #{key_list(removed_turkish_specific_fallback)}

  ## Intentionally Manual Active Entries (#{manual_keys.length})

  These are active, not stale. They are intentionally maintained because CatLocal supports an English fallback for every supported non-English iOS language, integer plural formatting, dynamic enum/model labels, and explicitly localized accessibility strings. Some visible literals are also held manually so the selected-language catalog remains complete and reviewable. The validator requires every manual key to retain an exact app-source call site, both locales, and a non-empty translation.

  | Key | Confirmed purpose | App source call sites |
  | --- | --- | --- |
  #{manual_table}

  ## Accessibility Native-Review Queue (#{accessibility_review_keys.length})

  These active labels, values, and hints need native-speaker review in Turkish. Their comments identify accessibility context, but engineering validation cannot establish natural spoken phrasing.

  #{key_list(accessibility_review_keys)}

  ## Maintenance Contract

  - Run `ruby scripts/validate_localizations.rb` before merging localization work.
  - Run `xcrun xcstringstool compile --dry-run` to validate String Catalog compilation.
  - Run this generator when the catalog changes so the manual-entry inventory stays reviewable.
  - Do not remove a manual entry solely because Xcode marks it unextracted; first prove that no selected-language, plural, model, enum, or accessibility lookup reaches it.
  - Native-speaker review of the Turkish translation remains a release gate and is not replaced by this engineering audit.
MARKDOWN

File.write(File.join(root, "docs/localization-catalog-audit.md"), output)
puts "Wrote docs/localization-catalog-audit.md"
