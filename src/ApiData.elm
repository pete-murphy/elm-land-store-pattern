module ApiData exposing
    ( ApiData
    , LoadingOrNot(..)
    , Value(..)
    , andMap
    , andThen
    , fail
    , fromMaybe
    , fromResult
    , isLoading
    , loading
    , map
    , notAsked
    , sequenceDict
    , succeed
    , toLoading
    , toMaybe
    , toMaybeError
    , toNotLoading
    , toPair
    , toRemoteData
    , traverseDict
    , traverseList
    , unwrap
    , value
    , withDefault
    )

import Dict
import RemoteData exposing (RemoteData)


type ApiData e a
    = ApiData (Internals e a)


type alias Internals e a =
    { value : Value e a
    , isLoading : Bool
    }


type Value e a
    = Empty
    | Failure e
    | Success a


type LoadingOrNot
    = Loading
    | NotLoading



-- CONSTRUCTORS


notAsked : ApiData e a
notAsked =
    ApiData { value = Empty, isLoading = False }


loading : ApiData e a
loading =
    ApiData { value = Empty, isLoading = True }


succeed : a -> ApiData e a
succeed a =
    ApiData { value = Success a, isLoading = False }


fail : e -> ApiData e a
fail error =
    ApiData { value = Failure error, isLoading = False }


fromResult : Result e a -> ApiData e a
fromResult result =
    case result of
        Ok a ->
            succeed a

        Err error ->
            fail error


fromMaybe : Maybe a -> ApiData e a
fromMaybe maybe =
    case maybe of
        Just a ->
            succeed a

        Nothing ->
            notAsked



-- COMBINATORS


mapLoading : (Bool -> Bool) -> ApiData e a -> ApiData e a
mapLoading f (ApiData internals) =
    ApiData { internals | isLoading = f internals.isLoading }


toLoading : ApiData e a -> ApiData e a
toLoading =
    mapLoading (\_ -> True)


toNotLoading : ApiData e a -> ApiData e a
toNotLoading =
    mapLoading (\_ -> False)


map : (a -> b) -> ApiData e a -> ApiData e b
map f (ApiData internals) =
    ApiData
        (case internals.value of
            Empty ->
                { value = Empty, isLoading = internals.isLoading }

            Failure error ->
                { value = Failure error, isLoading = internals.isLoading }

            Success a ->
                { value = Success (f a), isLoading = internals.isLoading }
        )


traverseList : (a -> ApiData e b) -> List a -> ApiData e (List b)
traverseList f =
    List.foldl
        (\a (ApiData acc) ->
            let
                data =
                    f a
            in
            case ( value data, acc.value ) of
                ( Success b, Success bs ) ->
                    ApiData { value = Success (b :: bs), isLoading = acc.isLoading || isLoading data }

                ( Failure error, _ ) ->
                    fail error

                ( _, Failure error ) ->
                    fail error

                ( _, _ ) ->
                    ApiData { value = Empty, isLoading = acc.isLoading || isLoading data }
        )
        (succeed [])


traversePair : (a -> ApiData e b) -> ( k, a ) -> ApiData e ( k, b )
traversePair f ( key, a ) =
    let
        data =
            unwrap (f a)
    in
    case data.value of
        Success b ->
            ApiData { value = Success ( key, b ), isLoading = data.isLoading }

        Failure error ->
            ApiData { value = Failure error, isLoading = data.isLoading }

        Empty ->
            ApiData { value = Empty, isLoading = data.isLoading }


traverseDict : (a -> ApiData e b) -> Dict.Dict comparable a -> ApiData e (Dict.Dict comparable b)
traverseDict f dict =
    dict
        |> Dict.toList
        |> traverseList (traversePair f)
        |> map Dict.fromList


sequenceDict : Dict.Dict comparable (ApiData e b) -> ApiData e (Dict.Dict comparable b)
sequenceDict =
    traverseDict identity


{-| Should match the semantics of the Monad instance for

    ExceptT e (MaybeT (Writer Any)) a

-}
andThen : (a -> ApiData e b) -> ApiData e a -> ApiData e b
andThen f (ApiData data) =
    case data.value of
        Success a ->
            let
                next =
                    unwrap (f a)
            in
            ApiData { value = next.value, isLoading = data.isLoading || next.isLoading }

        Failure err ->
            ApiData { value = Failure err, isLoading = data.isLoading }

        Empty ->
            ApiData { value = Empty, isLoading = data.isLoading }


andMap : ApiData e a -> ApiData e (a -> b) -> ApiData e b
andMap ma mf =
    mf |> andThen (\f -> map f ma)



-- DESTRUCTORS


withDefault : a -> ApiData e a -> a
withDefault default (ApiData internals) =
    case internals.value of
        Success a ->
            a

        _ ->
            default


toMaybe : ApiData e a -> Maybe a
toMaybe (ApiData internals) =
    case internals.value of
        Success a ->
            Just a

        _ ->
            Nothing


value : ApiData e a -> Value e a
value (ApiData internals) =
    internals.value


isLoading : ApiData e a -> Bool
isLoading (ApiData internals) =
    internals.isLoading


unwrap : ApiData e a -> Internals e a
unwrap (ApiData data) =
    data


toPair : ApiData e a -> ( LoadingOrNot, Value e a )
toPair (ApiData internals) =
    if internals.isLoading then
        ( Loading, internals.value )

    else
        ( NotLoading, internals.value )


toMaybeError : ApiData e a -> Maybe e
toMaybeError (ApiData internals) =
    case internals.value of
        Failure error ->
            Just error

        _ ->
            Nothing


toRemoteData : ApiData e a -> RemoteData e a
toRemoteData (ApiData internals) =
    case ( internals.value, internals.isLoading ) of
        ( _, True ) ->
            RemoteData.Loading

        ( Empty, _ ) ->
            RemoteData.NotAsked

        ( Failure error, _ ) ->
            RemoteData.Failure error

        ( Success a, _ ) ->
            RemoteData.Success a
