module Paginated exposing (..)

import Http
import Json.Decode
import Json.Decode.Pipeline
import Url.Builder


type alias Paginated a =
    { data : List a
    , pagination : Pagination
    }


type alias Pagination =
    { page : Int
    , limit : Int
    , totalPages : Int
    , totalCount : Int
    , hasNextPage : Bool
    , hasPreviousPage : Bool
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
        |> Json.Decode.Pipeline.required "pagination" paginationDecoder


paginationDecoder : Json.Decode.Decoder Pagination
paginationDecoder =
    Json.Decode.succeed Pagination
        |> Json.Decode.Pipeline.required "page" Json.Decode.int
        |> Json.Decode.Pipeline.required "limit" Json.Decode.int
        |> Json.Decode.Pipeline.required "totalPages" Json.Decode.int
        |> Json.Decode.Pipeline.required "totalCount" Json.Decode.int
        |> Json.Decode.Pipeline.required "hasNextPage" Json.Decode.bool
        |> Json.Decode.Pipeline.required "hasPreviousPage" Json.Decode.bool
