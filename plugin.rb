# name: discourse-szas
# about: collection of tweaks for szas.org
# version: 0.0.3
# authors: Thomas Kalka
# url: https://github.com/thoka/discourse-szas
# frozen_string_literal: true

require "onebox"

class Onebox::Engine::VimeoOnebox
  private

  def oembed_data
    return @oembed_data if @oembed_data
    response = Onebox::Helpers.fetch_response("https://vimeo.com/api/oembed.json?url=#{url}")
    @oembed_data = ::MultiJson.load(response, symbolize_keys: true)
  rescue StandardError
    "{}"
  end

  def og_data
    return @og_data if @og_data

    auth_key = SiteSetting.vimeo_api_token

    if auth_key.present?
      begin
        response =
          Onebox::Helpers.fetch_response(
            "https://api.vimeo.com/videos/#{oembed_data[:video_id]}",
            headers: {
              "authorization" => "Bearer #{auth_key}",
            },
          )
        video = ::MultiJson.load(response, symbolize_keys: true)
        @og_data =
          OpenStruct.new(
            title: video[:name],
            description: video[:description],
            image: video[:pictures][:sizes].last[:link],
          )
      rescue StandardError => e
        puts("🔴vimeo api call failed", e)
      end
    end

    @og_data ||= get_opengraph
  end
end

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
end

if false
  register_asset "stylesheets/vertretungsplan.scss"
  register_svg_icon "counterclockwise_arrows_button"
  register_svg_icon "superhero"
  register_svg_icon "x"

  after_initialize do
    require_relative "lib/vertretungsplan/cached_api_poller"

    module ::Vertretungsplan
      class Engine < ::Rails::Engine
        engine_name "vertretungsplan"
        isolate_namespace Vertretungsplan
      end

      Vertretungsplan::Engine.routes.draw { get "/vertretungsplan" => "vertretungsplan#index" }

      Discourse::Application.routes.append { mount Vertretungsplan::Engine, at: "/" }

      require_dependency "application_controller"

      class VertretungsplanController < ::ApplicationController
        # before_action :ensure_logged_in

        def index
          data = {
            updated_at: "2021-09-10T12:00:00",
            data: [
              {
                date: "2021-09-10",
                day_of_week: "Montag",
                lg: "123blauA",
                lessons: [
                  {
                    icon: "superhero",
                    time: "8:00 - 10:00",
                    subject: "Mathe",
                    teacher: "Herr Müller",
                    room: "A123",
                  },
                  {
                    icon: "x",
                    time: "10:00 - 12:00",
                    subject: "Deutsch",
                    teacher: "Frau Schmidt",
                    room: "A124",
                  },
                ],
              },
              {
                date: "2021-09-11",
                day_of_week: "Dienstag",
                lg: "123blauA",
                lessons: [
                  {
                    icon: "x",
                    time: "8:00 - 10:00",
                    subject: "Mathe",
                    teacher: "Herr Müller",
                    room: "A123",
                  },
                  {
                    icon: "x",
                    time: "10:00 - 12:00",
                    subject: "Deutsch",
                    teacher: "Frau Schmidt",
                    room: "A124",
                  },
                ],
              },
            ],
          }

          render json: data
        end
      end

      # class Engine < ::Rails::Engine
      #   isolate_namespace Vertretungsplan

      #   config.after_initialize do
      #     Discourse::Application.routes.append do
      #       mount ::Vertretungsplan::Engine, at: "/vertretungsplan"
      #     end
      #   end
      # end
    end
  end
end

### CHANGE EMAIL API

after_initialize do
  require_relative "app/controllers/admin_change_email/change_controller"

  module ::AdminChangeEmail
    class Engine < ::Rails::Engine
      engine_name "admin_change_email"
      isolate_namespace AdminChangeEmail
    end

    AdminChangeEmail::Engine.routes.draw do
      #scope module: "admin_change_email", constraints: AdminConstraint.new do
      #scope "/admin/plugins" do
      get "/admin/change-email" => "change#echo"
      post "/admin/change-email" => "change#update", :constraints => { format: :json }
      #end
      #end
      # get "admin-change-email" => "change#echo"
      # post "admin-change-email" => "change#echo", :constraints => { format: :json }
    end

    Discourse::Application.routes.append do
      mount AdminChangeEmail::Engine, at: "/" #, constraints: AdminConstraint.new
    end
  end
end

### PRIVATE THEMEN IN KATEGORIEN (Paket 65, Phase A1)

after_initialize do
  require_relative "lib/shared_topics"

  register_topic_custom_field_type(::SzasSharedTopics::CATEGORY_FIELD, :integer)

  # Klass-Patch (Regel im Ausgangspapier: ohne, wenn es geht; mit, wenn
  # nicht). Der Versuch, die Union über den Modifier
  # :topic_query_create_list_topics zu komponieren, scheitert
  # strukturell: .or verlangt strukturgleiche Relations, und der
  # Kategorien-Scope trägt aus remove_muted den category_users-Join,
  # den ein separat gebauter PM-Scope nie hat. Der Patch verbreitert
  # stattdessen die Kategorie-Klausel IN default_results selbst und
  # überlässt alles Weitere (Pin, Order, Paginierung) dem Core.
  # Die Specs in spec/queries/ tragen das Verhalten; ein Core-Umbau
  # an default_results schlägt dort sichtbar an.
  reloadable_patch do |plugin|
    TopicQuery.prepend(
      Module.new do
        define_method(:default_results) do |options = {}|
          raw_category = options[:category] || @options[:category]
          category_id = raw_category ? get_category_id(raw_category) : nil

          # Die Kategorie "An mich" ist eine Sicht: statt der Topics der
          # Kategorie (es gibt keine) zeigt sie die direkt an die
          # Person adressierten PMs. Anonym bleibt sie leer.
          if category_id && category_id == ::SzasSharedTopics.an_mich_category_id
            if @user
              return super(options.merge(category: nil, include_pms: true)).where(
                "topics.id IN (SELECT topic_id FROM topic_allowed_users WHERE user_id = ?)",
                @user.id,
              )
            else
              return super(options).none
            end
          end

          shared_ids =
            if category_id && @user
              ::SzasSharedTopics.shared_topic_ids_for_category(category_id)
            end

          if shared_ids.present?
            category_ids = Category.subcategory_ids(category_id) + [category_id]
            super(options.merge(category: nil, include_pms: true)).where(
              "topics.category_id IN (?) OR topics.id IN (?)", category_ids, shared_ids,
            )
          else
            super(options)
          end
        end
      end,
    )

    # In "An mich" schreiben ist sinnlos: ein echtes Topic dort wäre in
    # seiner eigenen Liste unsichtbar, weil die Liste nur PMs zeigt.
    Guardian.prepend(
      Module.new do
        def can_create_topic?(category_id)
          return false if category_id.to_i == ::SzasSharedTopics.an_mich_category_id

          super
        end
      end,
    )
  end

  ::SzasSharedTopics.ensure_an_mich_category

  module ::SzasMessages
    # Die virtuelle Kategorie "an mich": alle PMs der angemeldeten
    # Person, in Boxen gegliedert. "direkt" sind PMs, die allein an sie
    # adressiert sind; je Gruppe, die sie auf ein PM bekommt, gibt es
    # eine Box "group:<id>". Beide Unterscheidungen stehen in den
    # Teilnehmerschafts-Tabellen (topic_allowed_users /
    # topic_allowed_groups) - es wird nichts Extraes gespeichert.
    class SzasMessagesController < ::ApplicationController
      requires_login

      MAX_PER_PAGE = 30

      def index
        scope = filtered_scope
        topics =
          scope
            .order("topics.bumped_at DESC")
            .limit(MAX_PER_PAGE)

        render_serialized(
          topics,
          BasicTopicSerializer,
          root: false,
        )
      end

      # Die Boxen mit Zählern, fuer die Navigation (Baum "an mich" mit
      # "direct" und den Gruppen darunter).
      def boxes
        render_json_dump(user_boxes)
      end

      private

      def filtered_scope
        case params[:box]
        when "direct"
          direct_scope
        when /\Agroup:(\d+)\z/
          group_scope(Regexp.last_match(1).to_i)
        else
          Topic.private_messages_for_user(current_user)
        end
      end

      def direct_scope
        # "direkt" heißt: an mich adressiert - ein PM, das zusätzlich
        # eine Gruppe als Empfängerin hat, bleibt hier drin und taucht
        # zugleich in der Box dieser Gruppe auf (Sichten, keine Kopien).
        Topic.private_messages_for_user(current_user).where(
          "topics.id IN (SELECT topic_id FROM topic_allowed_users WHERE user_id = ?)",
          current_user.id,
        )
      end

      def group_scope(group_id)
        GroupUser.exists?(group_id: group_id, user_id: current_user.id) or
          raise Discourse::NotFound

        Topic
          .private_messages_for_user(current_user)
          .where(
            "topics.id IN (
              SELECT tg.topic_id FROM topic_allowed_groups tg
              JOIN group_users gu ON gu.group_id = tg.group_id
              WHERE gu.user_id = ? AND tg.group_id = ?
            )",
            current_user.id,
            group_id,
          )
      end

      def user_boxes
        groups =
          Group
            .joins(:group_users)
            .where(group_users: { user_id: current_user.id })
            .order(:full_name, :name)
            .pluck(:id, :name)

        base = Topic.private_messages_for_user(current_user)
        direct_count =
          base
            .where(
              "topics.id IN (SELECT topic_id FROM topic_allowed_users WHERE user_id = ?)",
              current_user.id,
            )
            .count

        [
          { key: "direct", name: "Direkt", count: direct_count },
          *groups.map do |group_id, name|
            {
              key: "group:#{group_id}",
              name: name,
              count:
                base.where(
                  "topics.id IN (
                    SELECT tg.topic_id FROM topic_allowed_groups tg
                    JOIN group_users gu ON gu.group_id = tg.group_id
                    WHERE gu.user_id = ? AND tg.group_id = ?
                  )",
                  current_user.id,
                  group_id,
                ).count,
            }
          end,
        ]
      end
    end
  end

  Discourse::Application.routes.append do
    get "/szas/my-messages" => "szas_messages/szas_messages#index"
    get "/szas/my-messages/boxes" => "szas_messages/szas_messages#boxes"
  end
end
