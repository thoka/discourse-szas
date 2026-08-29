# frozen_string_literal: true

# Private Themen in den Kategorien anzeigen (Paket 65, Phase A1)
#
# Ein privates Thema traegt ein TopicCustomField mit der Kennung des
# Bereichs, zu dem es gehoert ("szas_shared_category_id"). Das Thema
# erscheint fuer seine Teilnehmenden in der Liste dieses Bereichs und
# unter "/szas/nachrichten-an-mich" - sonst nirgends und fuer niemanden
# sonst. Die Zuordnung wird bis auf Weiteres per Konsole/API gesetzt
# (offene Frage im Paket 65); der Composer ist Nicht-Scope.
#
# Mechanismus: OR-Komposition zweier default_results-Skopes im
# Modifier :topic_query_create_list_topics - siehe
# doc/reports/beiträge-sharen-feed-injektion.md. Die PMs bleiben
# kategorielos; der Core-Konvention "PM can't have a category" folgt
# dieser Weg.

after_initialize do
  module ::SzasSharedTopics
    CATEGORY_FIELD = "szas_shared_category_id"

    def self.shared_topic_ids_for_category(category_id)
      TopicCustomField
        .where(name: CATEGORY_FIELD, value: category_id.to_s)
        .order("topic_custom_fields.topic_id")
        .pluck(:topic_id)
    end
  end

  register_topic_custom_field_type(::SzasSharedTopics::CATEGORY_FIELD, :integer)

  DiscoursePluginRegistry.register_modifier(self, :topic_query_create_list_topics) do |topics, options, topic_query|
    category_id = topic_query.options[:category_id]
    next topics if category_id.blank?
    next topics if topic_query.user.blank?

    shared_topic_ids = ::SzasSharedTopics.shared_topic_ids_for_category(category_id)
    next topics if shared_topic_ids.blank?

    # Der Kategorien-Scope (topics) und der PM-Scope stammen beide aus
    # default_results und sind deshalb strukturgleich - .or erlaubt die
    # Komposition, Limit/Order/Pinning fallen in einen Ausdruck.
    pm_scope =
      topic_query
        .default_results(options.merge(category: nil, include_pms: true))
        .where(id: shared_topic_ids)

    begin
      topics.or(pm_scope)
    rescue ArgumentError
      # .or verlangt identische Order-Klauseln; eine Kategorie mit
      # eigener sort_order bricht die Komposition. Degradation: die
      # Kategorie liste zeigt dann nur ihre regulären Topics.
      topics
    end
  end

  module ::SzasMessages
    class SzasMessagesController < ::ApplicationController
      requires_login

      def index
        list =
          TopicQuery.new(
            current_user,
            include_pms: true,
            per_page: 30,
          ).list_latest

        render_serialized(
          topics: TopicListSerializer.new(list, scope: guardian, root: false).as_json,
        )
      end
    end
  end

  Discourse::Application.routes.append do
    get "/szas/nachrichten-an-mich" => "szas_messages/szas_messages#index"
  end
end
