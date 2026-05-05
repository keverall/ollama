# SimpleCov configuration for bashcov
# This file is automatically loaded when bashcov runs from the project root.
# It filters out non-production code so coverage reports only show scripts/.
SimpleCov.start do
  # Exclude all test directories (relative paths from project root)
  add_filter "/tests/"
  add_filter "/test/"
  add_filter "/spec/"

  # Exclude mocks and fixtures (test support files)
  add_filter "/mocks/"
  add_filter "/fixtures/"
end

