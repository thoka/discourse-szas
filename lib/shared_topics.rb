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
#
# Diese Datei wird aus dem after_initialize-Block von plugin.rb
# geladen und definiert nur plain Ruby - die Plugin-DSL-Aufrufe
# (register_modifier, routes) stehen dort.

module ::SzasSharedTopics
  CATEGORY_FIELD = "szas_shared_category_id"
  AN_MICH_SLUG = "an-mich"

  def self.shared_topic_ids_for_category(category_id)
    TopicCustomField
      .where(name: CATEGORY_FIELD, value: category_id.to_s)
      .order("topic_custom_fields.topic_id")
      .pluck(:topic_id)
  end

  # Die Kategorie "An mich" ist ein echter Category-Record mit
  # gepatchter Listenansicht: sie zeigt jeder Person ihre direkt an sie
  # adressierten PMs. Es gibt sie genau einmal; position 0 sortiert sie
  # in Kategorien-Übersicht und Sidebar nach vorn.
  def self.ensure_an_mich_category
    category = Category.find_by(slug: AN_MICH_SLUG)
    if category.nil?
      category =
        Category.create!(
          name: "An mich",
          slug: AN_MICH_SLUG,
          user: Discourse.system_user,
          position: 0,
        )
    end
    # position -1: vor "uncategorized" (0) und allen Bereichen, damit
    # "An mich" in Übersicht und Sidebar zuerst steht
    category.update_column(:position, -1) if category.position != -1
    category
  rescue ActiveRecord::StatementInvalid, PG::Error
    # waehrend Migrationen steht die Tabelle noch nicht - der Bootlauf
    # danach legt sie an
    nil
  end

  def self.an_mich_category_id
    # bewusst ohne Cache: Tests setzen die DB zurueck, ein gemerkter
    # Identifier wuerde dort alt werden
    Category.where(slug: AN_MICH_SLUG).pick(:id)
  end
end
