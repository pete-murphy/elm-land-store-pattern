module Loadable exposing
    ( Loadable
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
    , toRemoteData
    , traverseDict
    , traverseList
    , unwrap
    , value
    , withDefault
    )

import Dict
import RemoteData exposing (RemoteData)


type Loadable e a
    = Loadable (Internals e a)


type alias Internals e a =
    { value : Value e a
    , isLoading : Bool
    }


type Value e a
    = Empty
    | Failure e
    | Success a



-- CONSTRUCTORS


notAsked : Loadable e a
notAsked =
    Loadable { value = Empty, isLoading = False }


loading : Loadable e a
loading =
    Loadable { value = Empty, isLoading = True }


succeed : a -> Loadable e a
succeed a =
    Loadable { value = Success a, isLoading = False }


fail : e -> Loadable e a
fail error =
    Loadable { value = Failure error, isLoading = False }


fromResult : Result e a -> Loadable e a
fromResult result =
    case result of
        Ok a ->
            succeed a

        Err error ->
            fail error


fromMaybe : Maybe a -> Loadable e a
fromMaybe maybe =
    case maybe of
        Just a ->
            succeed a

        Nothing ->
            notAsked



-- COMBINATORS


mapLoading : (Bool -> Bool) -> Loadable e a -> Loadable e a
mapLoading f (Loadable internals) =
    Loadable { internals | isLoading = f internals.isLoading }


toLoading : Loadable e a -> Loadable e a
toLoading =
    mapLoading (\_ -> True)


toNotLoading : Loadable e a -> Loadable e a
toNotLoading =
    mapLoading (\_ -> False)


map : (a -> b) -> Loadable e a -> Loadable e b
map f (Loadable internals) =
    Loadable
        (case internals.value of
            Empty ->
                { value = Empty, isLoading = internals.isLoading }

            Failure error ->
                { value = Failure error, isLoading = internals.isLoading }

            Success a ->
                { value = Success (f a), isLoading = internals.isLoading }
        )


traverseList : (a -> Loadable e b) -> List a -> Loadable e (List b)
traverseList f =
    List.foldl
        (\a (Loadable acc) ->
            let
                data =
                    f a
            in
            case ( value data, acc.value ) of
                ( Success b, Success bs ) ->
                    Loadable { value = Success (b :: bs), isLoading = acc.isLoading || isLoading data }

                ( Failure error, _ ) ->
                    fail error

                ( _, Failure error ) ->
                    fail error

                ( _, _ ) ->
                    Loadable { value = Empty, isLoading = acc.isLoading || isLoading data }
        )
        (succeed [])


traversePair : (a -> Loadable e b) -> ( k, a ) -> Loadable e ( k, b )
traversePair f ( key, a ) =
    let
        data =
            unwrap (f a)
    in
    case data.value of
        Success b ->
            Loadable { value = Success ( key, b ), isLoading = data.isLoading }

        Failure error ->
            Loadable { value = Failure error, isLoading = data.isLoading }

        Empty ->
            Loadable { value = Empty, isLoading = data.isLoading }


traverseDict : (a -> Loadable e b) -> Dict.Dict comparable a -> Loadable e (Dict.Dict comparable b)
traverseDict f dict =
    dict
        |> Dict.toList
        |> traverseList (traversePair f)
        |> map Dict.fromList


sequenceDict : Dict.Dict comparable (Loadable e b) -> Loadable e (Dict.Dict comparable b)
sequenceDict =
    traverseDict identity


{-| Should match the semantics of the Monad instance for

    ExceptT e (MaybeT (Writer Any)) a

-}
andThen : (a -> Loadable e b) -> Loadable e a -> Loadable e b
andThen f (Loadable data) =
    case data.value of
        Success a ->
            let
                next =
                    unwrap (f a)
            in
            Loadable { value = next.value, isLoading = data.isLoading || next.isLoading }

        Failure err ->
            Loadable { value = Failure err, isLoading = data.isLoading }

        Empty ->
            Loadable { value = Empty, isLoading = data.isLoading }


andMap : Loadable e a -> Loadable e (a -> b) -> Loadable e b
andMap ma mf =
    mf |> andThen (\f -> map f ma)



-- DESTRUCTORS


withDefault : a -> Loadable e a -> a
withDefault default (Loadable internals) =
    case internals.value of
        Success a ->
            a

        _ ->
            default


toMaybe : Loadable e a -> Maybe a
toMaybe (Loadable internals) =
    case internals.value of
        Success a ->
            Just a

        _ ->
            Nothing


value : Loadable e a -> Value e a
value (Loadable internals) =
    internals.value


isLoading : Loadable e a -> Bool
isLoading (Loadable internals) =
    internals.isLoading


unwrap : Loadable e a -> Internals e a
unwrap (Loadable data) =
    data


toMaybeError : Loadable e a -> Maybe e
toMaybeError (Loadable internals) =
    case internals.value of
        Failure error ->
            Just error

        _ ->
            Nothing


toRemoteData : Loadable e a -> RemoteData e a
toRemoteData (Loadable internals) =
    case ( internals.value, internals.isLoading ) of
        ( _, True ) ->
            RemoteData.Loading

        ( Empty, _ ) ->
            RemoteData.NotAsked

        ( Failure error, _ ) ->
            RemoteData.Failure error

        ( Success a, _ ) ->
            RemoteData.Success a
