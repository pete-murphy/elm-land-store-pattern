module Auth.User exposing
    ( User, Role(..)
    , decoder
    , id, username, email, role
    , isAdmin, isModerator, hasPermission
    )

{-| User data representation and role-based permissions.

@docs User, Role
@docs decoder
@docs id, username, email, role
@docs isAdmin, isModerator, hasPermission

-}

import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline as Pipeline


{-| User information from the authentication system
-}
type User
    = User UserData


type alias UserData =
    { id : String
    , username : String
    , email : String
    , role : Role
    , avatar : Maybe String
    , createdAt : String
    }


{-| User roles with hierarchical permissions
-}
type Role
    = Admin
    | Moderator
    | RegularUser



-- CONSTRUCTORS


{-| JSON decoder for User
-}
decoder : Decoder User
decoder =
    Decode.succeed UserData
        |> Pipeline.required "id" Decode.string
        |> Pipeline.required "username" Decode.string
        |> Pipeline.required "email" Decode.string
        |> Pipeline.required "role" roleDecoder
        |> Pipeline.optional "avatar" (Decode.nullable Decode.string) Nothing
        |> Pipeline.required "createdAt" Decode.string
        |> Decode.map User


roleDecoder : Decoder Role
roleDecoder =
    Decode.string
        |> Decode.andThen
            (\roleString ->
                case String.toLower roleString of
                    "admin" ->
                        Decode.succeed Admin

                    "moderator" ->
                        Decode.succeed Moderator

                    "user" ->
                        Decode.succeed RegularUser

                    _ ->
                        Decode.succeed RegularUser
            )



-- GETTERS


{-| Get user ID
-}
id : User -> String
id (User userData) =
    userData.id


{-| Get username
-}
username : User -> String
username (User userData) =
    userData.username


{-| Get email address
-}
email : User -> String
email (User userData) =
    userData.email


{-| Get user role
-}
role : User -> Role
role (User userData) =
    userData.role



-- PERMISSIONS


{-| Check if user is an admin
-}
isAdmin : User -> Bool
isAdmin user =
    role user == Admin


{-| Check if user is a moderator (or admin)
-}
isModerator : User -> Bool
isModerator user =
    case role user of
        Admin ->
            True

        Moderator ->
            True

        RegularUser ->
            False


{-| Check if user has permission for a specific action
-}
hasPermission : Permission -> User -> Bool
hasPermission permission user =
    case permission of
        CanModerateContent ->
            isModerator user

        CanDeleteAnyPost ->
            isAdmin user

        CanEditAnyPost ->
            isModerator user

        CanViewAdminPanel ->
            isAdmin user


{-| Specific permissions that can be checked
-}
type Permission
    = CanModerateContent
    | CanDeleteAnyPost
    | CanEditAnyPost
    | CanViewAdminPanel
