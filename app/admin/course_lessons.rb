ActiveAdmin.register CourseLesson do
  permit_params :course_module_id, :position, :title_en, :title_es, :summary_en, :summary_es,
                :body_markdown_en, :body_markdown_es, :stream_uid, :duration_seconds

  index do
    selectable_column
    id_column
    column :course
    column :course_module
    column :position
    column :title_en
    column :duration_seconds
    column :stream_uid
    column :created_at
    actions
  end

  filter :course_module,
         as: :select,
         collection: CourseModule.ordered.includes(:course).map { |mod| ["#{mod.course&.title_en} - #{mod.title_en}", mod.id] }
  filter :title_en
  filter :title_es
  filter :stream_uid
  filter :duration_seconds
  filter :position
  filter :created_at

  form do |f|
    f.inputs t("active_admin.course_lessons.sections.details") do
      f.input :course_module,
              collection: CourseModule.ordered.includes(:course).map { |mod| ["#{mod.course&.title_en} - #{mod.title_en}", mod.id] }
      f.input :position
      f.input :title_en
      f.input :title_es
      f.input :summary_en
      f.input :summary_es
    end

    f.inputs t("active_admin.course_lessons.sections.content") do
      f.input :body_markdown_en
      f.input :body_markdown_es
      f.input :stream_uid
      f.input :duration_seconds
    end

    f.actions
  end

  controller do
    def scoped_collection
      super.includes(course_module: :course)
    end
  end
end
