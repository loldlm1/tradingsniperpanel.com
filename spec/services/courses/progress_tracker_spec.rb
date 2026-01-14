require "rails_helper"

RSpec.describe Courses::ProgressTracker do
  let(:user) { create(:user) }
  let(:course) { create(:course) }
  let(:course_module) { create(:course_module, course: course) }
  let!(:lesson_one) { create(:course_lesson, course_module: course_module, duration_seconds: 500) }
  let!(:lesson_two) { create(:course_lesson, course_module: course_module, duration_seconds: 500, position: 1) }

  it "marks a lesson complete at 80 percent watched" do
    result = described_class.new(
      user: user,
      lesson: lesson_one,
      progress_seconds: 400,
      completed: false
    ).call

    expect(result.progress).to be_completed
    expect(result.enrollment).to be_present
  end

  it "updates enrollment progress when lessons complete" do
    described_class.new(user: user, lesson: lesson_one, progress_seconds: 500, completed: true).call
    described_class.new(user: user, lesson: lesson_two, progress_seconds: 500, completed: true).call

    enrollment = CourseEnrollment.find_by(user: user, course: course)
    expect(enrollment.progress_percent).to eq(100)
    expect(enrollment.completed_at).to be_present
  end
end
