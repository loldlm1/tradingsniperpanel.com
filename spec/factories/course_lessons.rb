FactoryBot.define do
  factory :course_lesson do
    association :course_module
    position { 0 }
    sequence(:title_en) { |n| "Lesson #{n}" }
    sequence(:title_es) { |n| "Leccion #{n}" }
    summary_en { "Lesson summary." }
    summary_es { "Resumen de la leccion." }
    body_markdown_en { "# Lesson Notes\n\n- Key idea" }
    body_markdown_es { "# Notas de leccion\n\n- Idea clave" }
    stream_uid { "demo_stream_uid" }
    duration_seconds { 600 }
  end
end
