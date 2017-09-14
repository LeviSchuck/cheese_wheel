defmodule CheeseWheel do
  def start_link(params) do
    CheeseWheel.Repo(params)
  end
  def get(repo_or_name, key) do
    CheeseWheel.Repo.get(repo_or_name, key)
  end
  def get(repo, name, key) do
    CheeseWheel.Repo.get(repo, name, key)
  end
  def set(repo, key, document) do
    CheeseWheel.Repo.set(repo, key, document)
  end
end
