ActiveAdmin.register CourseModule do
  permit_params :course_id, :position, :title_en, :title_es, :summary_en, :summary_es

  index do
    selectable_column
    id_column
    column :course
    column :position
    column :title_en
    column :title_es
    column :created_at
    actions
  end

  filter :course
  filter :title_en
  filter :title_es
  filter :position
  filter :created_at

  form do |f|
    f.inputs t("active_admin.course_modules.sections.details") do
      f.input :course,
              collection: Course.ordered.map { |course| ["#{course.title_en} (#{course.slug})", course.id] }
      f.input :position
      f.input :title_en
      f.input :title_es
      f.input :summary_en
      f.input :summary_es
    end
    f.actions
  end

  controller do
    def scoped_collection
      super.includes(:course)
    end
  end
end
