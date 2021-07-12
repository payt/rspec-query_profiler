# rspec-query_profiler

Tracks how many database queries it takes to complete an example, separated in queries used by the code under test and queries used by the test setup.

# Usage

```console
PROFILE=1 rspec spec/users/destroy_spec.rb

# app: 2, test: 1
```

When you need more details:

```console
PROFILE=2 rspec spec/users/destroy_spec.rb

# app: 2
#   User Load SELECT "users".* FROM "users" WHERE "users"."id" = $1 LIMIT $2 [15, 1]
#   User Destroy DELETE FROM "users" WHERE "users"."id" = $1 [15]

# test: 1
#   User Create INSERT INTO "users" ("email", "password") VALUES ($1, $2) RETURNING "id" ["test@example.com", "9be35b416ad44c24de8d7fa434ab5d5f"]
```

### Known limitations 
- It treats the `subject` as something special. RSpec doesn't care if you use `let` instead of `subject` in your specs, this gem does.
- It does not log queries that are triggered during the following callbacks: suite, all, context.

### Todo
- Create a diffable log of all queries which can be checked into the repo to be able to track changes.
- Make it visual in the console log which queries are executed more than once.
