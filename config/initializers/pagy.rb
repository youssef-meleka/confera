require "pagy/extras/headers"    # Link / Total-Count / ... response headers
require "pagy/extras/limit"      # lets the client choose ?per_page=
require "pagy/extras/overflow"   # page past the end -> empty page, not an error

Pagy::DEFAULT[:limit]       = 20
Pagy::DEFAULT[:limit_param] = :per_page
Pagy::DEFAULT[:limit_max]   = 100 # clients can't request ?per_page=1000000
Pagy::DEFAULT[:overflow]    = :empty_page

Pagy::DEFAULT.freeze
