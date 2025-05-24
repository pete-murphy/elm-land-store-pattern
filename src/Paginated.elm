module Paginated exposing (..)

import Http
import Json.Decode
import Json.Decode.Pipeline
import Url.Builder


type alias Paginated a =
    { data : List a
    , morePages : Bool
    , page : Int
    , perPage : Int
    , total : Int
    }


type alias Request =
    { headers : List Http.Header
    , pathSegments : List String
    , queryParams : List Url.Builder.QueryParameter
    , config : Config
    }


type alias Config =
    { perPage : Int }


decoder : Json.Decode.Decoder a -> Json.Decode.Decoder (Paginated a)
decoder decoderA =
    Json.Decode.succeed Paginated
        |> Json.Decode.Pipeline.required "data" (Json.Decode.list decoderA)
        |> Json.Decode.Pipeline.required "more_pages" Json.Decode.bool
        |> Json.Decode.Pipeline.required "page" Json.Decode.int
        |> Json.Decode.Pipeline.required "per_page" Json.Decode.int
        |> Json.Decode.Pipeline.required "total" Json.Decode.int
