require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
end

helpers do
  def completed?(todo)
    "complete" if todo[:completed]
  end

  def list_completed?(list)
    "complete" if count_incomplete_todos(list) == 0 &&
                    count_total_todos(list) > 0
  end

  def count_incomplete_todos(list)
    list[:todos].reduce(0) do |total, todo|
      !todo[:completed] ? total + 1 : total
    end
  end

  def count_total_todos(list)
    list[:todos].size
  end
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# View list of lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Return an error message if name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    'List must be between 1 and 100 characters.'
  elsif session[:lists].any? { |list| list[:name] == name }
    'List name must be unique.'
  end
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect "/lists"
  end
end

# Update an existing todo list
post "/lists/:index" do
  list_name = params[:list_name].strip
  @list_index = params[:index].to_i
  @current_list = session[:lists][@list_index]

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @current_list[:name] = list_name
    session[:success] = 'The list has been renamed.'
    redirect "/lists/#{@list_index}"
  end
end

# View a todo list
get "/lists/:index" do
  @list_index = params[:index].to_i
  @current_list = session[:lists][@list_index]
  # @current_list[:todos] = @current_list[:todos].partition do |todo|
  #   !todo[:completed]
  # end.flatten

  erb :single_list, layout: :layout
end

# View single list name editing page
get "/lists/:index/edit" do
  @list_index = params[:index].to_i
  @current_list = session[:lists][@list_index]


  erb :edit_list, layout: :layout
end

# Delete an entire todo list
post "/lists/:index/delete" do
  list_index = params[:index].to_i
  deleted_list = session[:lists].delete_at list_index
  session[:success] = "The list '#{deleted_list[:name]}' has been deleted."

  redirect "/lists"
end

def error_for_todo_name(name)
  if !(1..100).cover? name.size
    'Todo must be between 1 and 100 characters.'
  end
end

# Add a todo list to a page
post "/lists/:index/todos" do
  todo = params[:todo].strip
  @list_index = params[:index].to_i
  @current_list = session[:lists][@list_index]

  error = error_for_todo_name(todo)
  if error
    session[:error] = error
    erb :single_list, layout: :layout
  else
    @current_list[:todos] << { name: todo, completed: false }
    session[:success] = "The todo '#{todo}' was added."
    redirect "/lists/#{@list_index}"
  end
end

# Delete a todo list item
post "/lists/:list_index/todos/:todo_index/delete" do
  @list_index = params[:list_index].to_i
  @todo_index = params[:todo_index].to_i
  @current_list = session[:lists][@list_index]
  deleted_todo = @current_list[:todos].delete_at @todo_index
  session[:success] = "The todo '#{deleted_todo[:name]}' has been deleted."

  redirect "/lists/#{@list_index}"
end

# Mark a todo list item as complete
def mark_done_at(list_index, todo_index)
  current_list = session[:lists][list_index]
  current_todo = current_list[:todos][todo_index]
  current_todo[:completed] = true

  current_todo
end


def toggle(todo, status)
  if status
    todo[:completed] = true
    session[:success] = "The todo '#{todo[:name]}' has been checked off."
  else
    todo[:completed] = false
    session[:success] = "The todo '#{todo[:name]}' has been unchecked."
  end
end

# Toggle a todo list item as complete or incomplete
post "/lists/:list_index/todos/:todo_index" do
  @list_index = params[:list_index].to_i
  @todo_index = params[:todo_index].to_i
  @current_list = session[:lists][@list_index]
  @current_todo = @current_list[:todos][@todo_index]
  change_status_to = params[:completed] == "true"

  toggle @current_todo, change_status_to

  redirect "/lists/#{@list_index}"
end

# Mark all todos as complete
post "/lists/:list_index/complete_all" do
  @list_index = params[:list_index].to_i
  @current_list = session[:lists][@list_index]
  @current_list[:todos].each { |todo| todo[:completed] = true }

  session[:success] = "All todos have been completed."
  redirect "/lists/#{@list_index}"
end