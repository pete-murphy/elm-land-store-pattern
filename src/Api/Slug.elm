module Api.Slug exposing
    ( Slug
    , decoder
    , encoder
    , fromRoute
    , toString
    )

import Json.Decode as Decode
import Json.Encode as Encode
import Route exposing (Route)


type Slug
    = Slug String


decoder : Decode.Decoder Slug
decoder =
    Decode.string
        |> Decode.map Slug


encoder : Slug -> Encode.Value
encoder (Slug slug) =
    Encode.string slug


toString : Slug -> String
toString (Slug slug) =
    slug


fromRoute : Route { slug : String } -> Slug
fromRoute route =
    Slug route.params.slug
