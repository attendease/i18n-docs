# rake i18n:missing_keys
# rake i18n:import_translations
# rake i18n:export_translations

namespace :i18n do

  desc "Find and list translation keys that do not exist in all locales"
  task :missing_keys => :environment do
    finder = LocalchI18n::MissingKeysFinder.new(I18n.backend)
    finder.find_missing_keys
  end

  desc "Download translations from Google Drive Spreadsheet and save them to YAML files."
  task :import_translations => :environment do
    translations_importer = LocalchI18n::TranslationsImporter.new()
    translations_importer.download_files
    translations_importer.import_translations
    # translations_importer.clean_up
  end

  desc "Export all language files to CSV files first, Google Drive second (only files contained in en folder are considered)"
  task :export_translations => :environment do
    translations_exporter = LocalchI18n::TranslationsExporter.new()
    translations_exporter.export_translations
    translations_exporter.upload_files
    # translations_exporter.clean_up
  end

end
