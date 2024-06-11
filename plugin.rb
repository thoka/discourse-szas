# name: discourse-szas
# about: collection of tweaks for szas.org
# version: 0.0.2
# authors: Thomas Kalka
# url: https://github.com/thoka/discourse-szas
# frozen_string_literal: true

after_initialize do
  # enabled_site_setting :szasAdaptions_enabled

  module MailPrefixShortener
    module BuildEmailHelperExtension
      def build_email(to, opts)
        opts ||= {}

        # use only subcategory name in subject
        if opts[:show_category_in_subject].present?
          opts[:show_category_in_subject] = opts[:show_category_in_subject].split("/").last
        end

        # put [] around tags in subject
        if opts[:show_tags_in_subject].present?
          tags = opts[:show_tags_in_subject].split(" ")
          tags = tags.map { |tag| "[#{tag}]" }
          opts[:show_tags_in_subject] = tags.join(" ")
        end

        super(to, opts)
      end
    end
  end

  # Fix following issue:
  # In d/rails Discourse.current_hostname returns "localhost", but
  # in unicorn Discourse.current_hostname returns "127.0.0.1"
  module FixLocalhostSitename
    def current_hostname
      return res = super unless res == "127.0.0.1"
      "localhost"
    end
  end

  module AllowPublishingOfPrivateTopics
    def local_topic(url, route, opts)
      puts "🟣🟣🟣local_topic: #{url} #{route} #{opts}"
      if current_user = User.find_by(id: opts[:user_id])
        puts " 🟣user: #{current_user.username}"

        if current_category = Category.find_by(id: opts[:category_id])
          puts " 🟣category: #{current_category.name}"
          return unless Guardian.new(current_user).can_see_category?(current_category)
          puts " ... allowed"
        end

        if current_topic = Topic.find_by(id: opts[:topic_id])
          return unless Guardian.new(current_user).can_see_topic?(current_topic)
          puts " 🟣is allowed to see current topic: #{current_topic.id} #{current_topic.title}"
        end
      end

      return unless topic = Topic.find_by(id: route[:id] || route[:topic_id])
      return if topic.private_message?

      if current_category.blank? || current_category.id != topic.category_id
        return unless Guardian.new(current_user).can_see_topic?(topic)
        puts " 🟣is allowed to see referenced topic: #{topic.id} #{topic.title}"
      end

      puts " 🟣success!"
      topic
    end
  end

  module DedupCSS
    def dedup_styles
      @fragment.css("[style]").each { |element| element["style"] = dedup_style element["style"] }
    end

    def to_html
      # needs to be before class + id strip because we need to style redacted
      # media and also not double-redact already redacted from lower levels
      replace_secure_uploads_urls if SiteSetting.secure_uploads?
      strip_classes_and_ids
      replace_relative_urls
      dedup_styles

      @fragment.to_html
    end
  end

  reloadable_patch do |plugin|
    UserNotifications.class_eval { prepend MailPrefixShortener::BuildEmailHelperExtension }
    Discourse.singleton_class.prepend FixLocalhostSitename
    Oneboxer.singleton_class.prepend AllowPublishingOfPrivateTopics
    Email::Styles.prepend DedupCSS
  end
end
