require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:one)
    sign_in users(:one)
  end

  # Groups was retired from the nav: the index + creation entry points are blocked
  # (redirect to the app root). Member-scoped actions below stay reachable.
  test "index is blocked (redirects to root)" do
    get projects_url
    assert_redirected_to authenticated_root_path
  end

  test "new is blocked (redirects to root)" do
    get new_project_url
    assert_redirected_to authenticated_root_path
  end

  test "create is blocked (redirects to root, creates nothing)" do
    assert_no_difference("Project.count") do
      post projects_url, params: { project: { title: "New Project" } }
    end
    assert_redirected_to authenticated_root_path
  end

  test "should show project" do
    get project_url(@project)
    assert_response :success
  end

  test "should get edit" do
    get edit_project_url(@project)
    assert_response :success
  end

  test "should update project" do
    patch project_url(@project), params: { project: { title: "Updated Title" } }
    assert_redirected_to project_url(@project)
  end

  test "should leave project" do
    delete project_url(@project)
    assert_redirected_to projects_url
  end
end
