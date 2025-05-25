module Auth exposing (User, onPageLoad, viewCustomPage)

import Auth.Action
import Auth.Credentials exposing (Credentials)
import Auth.Route
import Loadable
import Route exposing (Route)
import Shared
import View exposing (View)


type alias User =
    { credentials : Credentials }


{-| Called before an auth-only page is loaded.
-}
onPageLoad : Shared.Model -> Route () -> Auth.Action.Action User
onPageLoad shared route =
    case shared of
        Err _ ->
            Auth.Action.loadCustomPage

        Ok okShared ->
            case ( Loadable.value okShared.credentials, Loadable.isLoading okShared.credentials ) of
                ( Loadable.Success credentials, _ ) ->
                    -- User is logged in, proceed to load the page
                    Auth.Action.loadPageWithUser { credentials = credentials }

                ( _, True ) ->
                    -- Should only be reachable in error case
                    Auth.Action.loadCustomPage

                ( _, False ) ->
                    -- User is not logged in, redirect them
                    Auth.Action.pushRoute
                        (Auth.Route.toLogin route)


{-| Renders whenever `Auth.Action.loadCustomPage` is returned from `onPageLoad`.
-}
viewCustomPage : Shared.Model -> Route () -> View Never
viewCustomPage shared _ =
    View.fromString "Should not be reachable"
