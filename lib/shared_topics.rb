# frozen_string_literal: true

# Private Nachrichten als Sichten (Paket 65, Phase A1)
#
# Nach dem gescheiterten An-mich-Patch (doc/reports/
# virtuelle-kategorien.md, 30.08.2026) beruehrt das Plugin keinen
# Core-Pfad mehr: keine Klass-Patches, keine Kategorie-Kopplung. Die
# Sichten leben in den Endpunkten /szas/my-messages* (plugin.rb) und
# lesen allein die Teilnehmerschafts-Tabellen.

module ::SzasSharedTopics
  CATEGORY_FIELD = "szas_shared_category_id"

  def self.shared_topic_ids_for_category(category_id)
    TopicCustomField
      .where(name: CATEGORY_FIELD, value: category_id.to_s)
      .order("topic_custom_fields.topic_id")
      .pluck(:topic_id)
  end
end
