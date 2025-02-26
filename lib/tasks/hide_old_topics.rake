# frozen_string_literal: true

namespace :szas do
  desc "Hide old topics"
  task hide_old_topics: :environment do
    require_dependency "topic"
    require_dependency "user"
    require_dependency "topic_user"

    SiteSetting.force_https = false if Rails.env.development?

    category_ids = ENV["CATEGORIES"] || "25,63" # Schule Informiert und Eltern unter sich
    date_cutoff = ENV["DATE_CUTOFF"] || "2024-08-01" # 2Das Stichtagsdatum (z. B. 2023-01-01)
    testrun = !["0", "false", "False", "FALSE", "", "-1", nil].include?(ENV["TESTRUN"])

    tag_group_id = 12
    tag_group = TagGroup.find(tag_group_id)
    excluded_tags = tag_group.tags.pluck(:name)

    # puts "Tags in Taggruppe #{tag_group_id}: #{excluded_tags.join(", ")}"

    category_ids = category_ids.split(",").map(&:to_i)
    date_cutoff = Date.parse(date_cutoff)

    if category_ids.length == 0 || date_cutoff.nil?
      puts "Bitte stelle sicher, dass CATEGORY_ID und DATE_CUTOFF als Umgebungsvariablen gesetzt sind."
      exit 1
    end

    subcategories = Category.where(parent_category_id: category_ids).pluck(:id)

    puts "Starte das Verstecken von Themen in den Bereichen '#{category_ids}', die älter als #{date_cutoff} sind."
    # puts "Subkategorien: #{subcategories.join(", ")}"

    topics =
      Topic.where(category_id: subcategories, archetype: Archetype.default).where(
        "created_at < ?",
        date_cutoff,
      )

    topics.find_each do |topic|
      begin
        @topic = topic
        @top_category = topic.category
        while @top_category.parent_category_id
          @top_category = Category.find(@top_category.parent_category_id)
        end

        if @topic.id == @topic.category.topic_id
          if @topic.title.include?("Kategorie")
            @topic.title.gsub!("die Kategorie", "den Bereich")
            @topic.save! unless testrun
          end
          next
        end

        @info_shown = false

        def show_info
          return if @info_shown
          puts "Thema #{@topic.id} in #{@top_category.slug}/#{@topic.category.slug}:"
          puts "  '#{@topic.title}'"
          puts "  erstellt: #{@topic.created_at} bearbeitet: #{@topic.updated_at}"
          @info_shown = true
        end

        skip_category_endings = "-alle,-ms,-os,-ps".split(",")

        if skip_category_endings.any? { |ending| @topic.category.slug.ends_with?(ending) }
          # puts " ... überspringe Kategorie (Endung)"
          next
        end

        if @topic.pinned_globally || @topic.pinned_until
          # puts " ... überspringe angepinntes Thema"
          next
        end

        topic_tags = topic.tags.map(&:name)
        live_to = date_cutoff

        if (topic_tags & excluded_tags).any?
          for tag in excluded_tags
            if topic_tags.include? tag
              live_to = @topic.updated_at + 1.month if tag.ends_with?(":Monat")
              live_to = @topic.updated_at + 1.year if tag.ends_with?(":Jahr")
              live_to = Date.today + 10.years if tag.ends_with?(":immer")
            end
          end
        end

        if live_to && Date.today < live_to
          show_info
          puts "   ... hat Ablaufdatum (#{live_to}) nicht erreicht."
          if (!@topic.visible || @topic.archived)
            show_info
            if testrun
              puts "  # ... würde wieder gezeigt"
            else
              puts "  ! ... wird wieder gezeigt"
              @topic.update!(visible: true, archived: false)
            end
          end
          next
        end

        if (!@topic.visible && @topic.archived)
          # puts "  + ... ist bereits versteckt"
          next
        end

        show_info
        if testrun
          puts "  # ... Thema würde versteckt"
        else
          @topic.update!(visible: false, archived: true) unless testrun
          puts "  ! ... Thema wurde versteckt"
        end
      rescue => e
        show_info
        puts "!!! Fehler: #{e.message}"
      end
      puts
    end

    puts "Verstecken abgeschlossen."
  end
end
