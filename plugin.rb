# name: discourse-szas
# about: collection of tweaks for szas.org
# version: 0.0.1
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

  reloadable_patch do |plugin|
    UserNotifications.class_eval { prepend MailPrefixShortener::BuildEmailHelperExtension }
  end
end
