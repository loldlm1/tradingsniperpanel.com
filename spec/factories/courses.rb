FactoryBot.define do
  factory :course do
    sequence(:slug) { |n| "course-#{n}" }
    status { "published" }
    category { "introduction" }
    position { 0 }
    sequence(:title_en) { |n| "Course #{n}" }
    sequence(:title_es) { |n| "Curso #{n}" }
    summary_en { "Quick course summary." }
    summary_es { "Resumen rapido del curso." }
    description_en { "Course description." }
    description_es { "Descripcion del curso." }
  end
end
