require "rails_helper"

RSpec.describe "Admin course content", type: :request do
  let(:admin) { create(:user, :admin) }

  before do
    sign_in admin, scope: :user
  end

  it "allows admins to create and update course modules" do
    course = create(:course)

    expect do
      post admin_course_modules_path, params: {
        course_module: {
          course_id: course.id,
          position: 0,
          title_en: "Module 1",
          title_es: "Modulo 1",
          summary_en: "Module summary",
          summary_es: "Resumen del modulo"
        }
      }
    end.to change(CourseModule, :count).by(1)

    module_record = CourseModule.order(:id).last
    expect(response).to redirect_to(admin_course_module_path(module_record))

    patch admin_course_module_path(module_record), params: {
      course_module: {
        title_en: "Module 1 Updated",
        title_es: "Modulo 1 Actualizado"
      }
    }

    expect(response).to redirect_to(admin_course_module_path(module_record))
    expect(module_record.reload.title_en).to eq("Module 1 Updated")
  end

  it "allows admins to create and update course lessons" do
    course_module = create(:course_module)

    expect do
      post admin_course_lessons_path, params: {
        course_lesson: {
          course_module_id: course_module.id,
          position: 0,
          title_en: "Lesson 1",
          title_es: "Leccion 1",
          summary_en: "Lesson summary",
          summary_es: "Resumen de la leccion",
          body_markdown_en: "# Lesson\n\n- Point",
          body_markdown_es: "# Leccion\n\n- Punto",
          stream_uid: "stream_123",
          duration_seconds: 900
        }
      }
    end.to change(CourseLesson, :count).by(1)

    lesson = CourseLesson.order(:id).last
    expect(response).to redirect_to(admin_course_lesson_path(lesson))

    patch admin_course_lesson_path(lesson), params: {
      course_lesson: {
        title_en: "Lesson 1 Updated",
        duration_seconds: 1200
      }
    }

    expect(response).to redirect_to(admin_course_lesson_path(lesson))
    expect(lesson.reload.title_en).to eq("Lesson 1 Updated")
  end
end
