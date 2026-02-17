# frozen_string_literal: true

namespace :szas do
  desc "Setzt Benachrichtigungsstufe 'Verfolgen' in der Kategorie 'Schulleben' für alle Mitglieder der Gruppe 'sg', falls noch kein Wert gesetzt ist"
  task set_schulleben_tracking: :environment do
    group_name = ENV["GROUP"] || "sg"
    category_name = ENV["CATEGORY"] || "Schulleben"

    group = Group.find_by(name: group_name)
    unless group
      puts "Fehler: Gruppe '#{group_name}' nicht gefunden."
      exit 1
    end

    category = Category.find_by(name: category_name)
    unless category
      puts "Fehler: Kategorie '#{category_name}' nicht gefunden."
      exit 1
    end

    tracking = CategoryUser.notification_levels[:tracking]

    puts "Gruppe: #{group.name} (#{group.users.count} Mitglieder)"
    puts "Kategorie: #{category.name} (ID: #{category.id})"
    puts "Setze Benachrichtigungsstufe 'Verfolgen' für Mitglieder ohne gesetzten Wert...\n\n"

    count_set = 0
    count_skipped = 0
    count_error = 0

    group.users.find_each do |user|
      begin
        existing = CategoryUser.find_by(user_id: user.id, category_id: category.id)

        if existing
          puts "  Überspringe #{user.username} (bereits gesetzt: #{existing.notification_level})"
          count_skipped += 1
          next
        end

        CategoryUser.set_notification_level_for_category(user, tracking, category.id)
        puts "  Gesetzt: #{user.username}"
        count_set += 1
      rescue => e
        puts "  Fehler bei #{user.username}: #{e.message}"
        count_error += 1
      end
    end

    puts "\nFertig: #{count_set} gesetzt, #{count_skipped} übersprungen, #{count_error} Fehler."
  end
end
