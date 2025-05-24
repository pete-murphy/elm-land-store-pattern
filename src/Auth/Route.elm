module Auth.Route exposing
    ( fromLogin
    , toLogin
    )

import Dict exposing (Dict)
import Maybe.Extra
import Route exposing (Route)
import Route.Path


toLogin :
    Route any
    ->
        { path : Route.Path.Path
        , query : Dict String String
        , hash : Maybe String
        }
toLogin route =
    { path = Route.Path.Login
    , query =
        if route.url.path == "/" then
            Dict.empty

        else
            Dict.fromList
                [ ( "from", route.url.path ) ]
    , hash = Nothing
    }


fromLogin :
    Route any
    -> Route.Path.Path
fromLogin route =
    Dict.get "from" route.query
        |> Maybe.andThen Route.Path.fromString
        |> Maybe.Extra.filter
            (\path ->
                Basics.not
                    (List.member path
                        [ Route.Path.Login
                        , Route.Path.NotFound_
                        ]
                    )
            )
        |> Maybe.withDefault Route.Path.Home_
