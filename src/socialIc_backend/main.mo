import Time "mo:base/Time";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Debug "mo:base/Debug";
import Array "mo:base/Array";

actor SocialIC_backend {

    type Profile = {
        id: Principal;
        username: Text;
        bio: Text;

    };

    type Post = {
        id: Nat;
        author: Principal;
        content: Text;
        timestamp: Int;
        comments: [Nat];  // Lista de IDs de comentarios asociados con este post
        
    };

    type FollowRequest = {
    follower: Principal;
    followee: Principal;
    accepted: Bool;
    };

    type Comment = {
    id: Nat;
    postId: Nat;
    author: Principal;
    content: Text;
    timestamp: Int;
    };

    stable var commentsArray : [Comment] = [];
    var nextCommentId : Nat = 0;


    stable var followRequests : [FollowRequest] = [];


    stable var profilesArray : [Profile] = [];  // Almacén estable para los perfiles
    var profilesMap : HashMap.HashMap<Principal, Profile> = HashMap.HashMap(10, Principal.equal, Principal.hash);

    stable var postsArray: [Post] = [];
    var nextPostId : Nat = 0; // ID Incremental para los posts 

    // Cargar el HashMap desde el Array estable cuando el canister se inicia
    public func init() {
        for (profile in profilesArray.vals()) {
            profilesMap.put(profile.id, profile);
        }
    };

    public shared(msg: { caller: Principal }) func createProfile(username: Text, bio: Text) : async Bool {
        let newProfile : Profile = {
            id = msg.caller;
            username = username;
            bio = bio;
        };

        profilesMap.put(msg.caller, newProfile);  // Guardar en HashMap para acceso rápido
        profilesArray := Array.append(profilesArray, [newProfile]);  // Guardar en el Array estable

        return true;
    };

    public query func getAllProfiles() : async [Profile] {
        return profilesArray;  // Devolver el Array estable con todos los usuarios
    };

    public query(msg) func getMyProfile() : async ?Profile {
        return profilesMap.get(msg.caller);  // Devolver el perfil del HashMap del principal 
    };

    public query(msg) func whoAmI() : async Principal {
        return msg.caller;
    };

    public shared(msg: { caller: Principal }) func editProfile(newUsername: Text, newBio: Text) : async Text {
        // Buscar el perfil en el HashMap
        let maybeProfile = profilesMap.get(msg.caller);

        switch maybeProfile {
            case (?profile) {
                // Crear una versión actualizada del perfil
                let updatedProfile : Profile = {
                    id = profile.id;
                    username = newUsername;
                    bio = newBio;
                };

                // Actualizar el perfil en el HashMap
                profilesMap.put(msg.caller, updatedProfile);

                // Actualizar el perfil en el Array estable
                profilesArray := Array.map<Profile, Profile>(profilesArray, func(p: Profile) : Profile {
                    if (p.id == msg.caller) {
                        updatedProfile;
                    } else {
                        p;
                    }
                });

                return "Perfil Actualizado Exitosamente";
            };
            case null {
                // Si no se encuentra el perfil, devolver false
                return "Perfil no actualizado, no se encontro perfil";
            };
        }
    };

    public shared(msg: {caller: Principal }) func createPost(content: Text) : async Text{
        let newPost : Post = {
            id = nextPostId;
            author = msg.caller;
            content = content;
            timestamp = Time.now();
            comments = [];
    };

        postsArray := Array.append(postsArray, [newPost]);
        nextPostId += 1;

        return "Post creado con éxito";
    };

    public query func getAllPosts() : async [Post] {
        return postsArray;
};

    public query(msg) func getMyPosts() : async [Post] {
        return Array.filter(postsArray, func(post: Post) : Bool { post.author == msg.caller });
};

    public shared(msg: { caller: Principal }) func editPost(postId: Nat, newContent: Text) : async Text {
        var postEdited = false;

        // Mapear el array de posts para encontrar y actualizar el post correspondiente
        postsArray := Array.map<Post, Post>(postsArray, func(post: Post) : Post {
            if (post.id == postId and post.author == msg.caller) {
                postEdited := true;  // Indicamos que el post fue editado
                { id = post.id;
                author = post.author;
                content = newContent;
                timestamp = Time.now();
                comments = post.comments};
            } else {
                post
            }
        });

        if (postEdited) {
            return "Post actualizado con éxito";
        } else {
            return "Post no encontrado o no tienes permiso para editarlo";
        };
    };

    public shared(msg: { caller: Principal }) func deletePost(postId: Nat) : async Text {
    var postDeleted = false;

    // Filtramos los posts y eliminamos el que coincida con el postId y el autor sea el caller
    postsArray := Array.filter(postsArray, func(post: Post) : Bool {
        if (post.id == postId and post.author == msg.caller) {
            postDeleted := true;
            false  // No incluimos este post en el array resultante, lo eliminamos
        } else {
            true  // Mantenemos el post en el array
        }
    });

    if (postDeleted) {
        return "Post eliminado con éxito";
    } else {
        return "Post no encontrado o no tienes permiso para eliminarlo";
    };
    };

    public shared(msg: { caller: Principal }) func sendFollowRequest(followee: Principal) : async Text {
    let request : FollowRequest = {
        follower = msg.caller;
        followee = followee;
        accepted = false;
    };

        followRequests := Array.append(followRequests, [request]);

        return "Solicitud de seguimiento enviada";
    };

    public shared(msg: { caller: Principal }) func acceptFollowRequest(follower: Principal) : async Text {
        var requestAccepted = false;

        followRequests := Array.map<FollowRequest, FollowRequest>(followRequests, func(request: FollowRequest) : FollowRequest {
            if (request.follower == follower and request.followee == msg.caller and not request.accepted) {
                requestAccepted := true;
                { follower = request.follower; followee = request.followee; accepted = true }
            } else {
                request
            }
        });

        if (requestAccepted) {
            return "Solicitud de seguimiento aceptada";
        } else {
            return "Solicitud de seguimiento no encontrada o ya aceptada";
        };
    };

    public shared(msg: { caller: Principal }) func createComment(postId: Nat, content: Text) : async Text {
        let maybePost = Array.find(postsArray, func(post: Post) : Bool {
            post.id == postId
        });

        // Usamos un bloque switch para manejar el valor opcional de maybePost
        switch maybePost {
            case (?post) {
                // Verificamos si el usuario es el autor del post o un seguidor aceptado
                let isFolloweeOrAuthor = (Array.find(followRequests, func(request: FollowRequest) : Bool {
                    request.follower == msg.caller and request.accepted and request.followee == post.author
                }) != null) or post.author == msg.caller;

                if (isFolloweeOrAuthor) {
                    let newComment : Comment = {
                        id = nextCommentId;
                        postId = postId;
                        author = msg.caller;
                        content = content;
                        timestamp = Time.now();
                    };

                    commentsArray := Array.append(commentsArray, [newComment]);  // Guardamos el comentario
                    nextCommentId += 1;

                    // Añadimos el ID del comentario al post correspondiente
                    postsArray := Array.map<Post, Post>(postsArray, func(p: Post) : Post {
                        if (p.id == postId) {
                            { id = p.id; author = p.author; content = p.content; timestamp = p.timestamp; comments = Array.append(p.comments, [newComment.id]) }
                        } else {
                            p
                        }
                    });

                    return "Comentario creado con éxito";
                } else {
                    return "No tienes permiso para comentar en este post";
                }
            };
            case null {
                return "Post no encontrado";
            };
        };
    };

    // Funcion para obtener los posts de los usuarios alos que el usuario autenticado sigue
    public query(msg) func getFolloweesPosts() : async [Post] {
        let myFollowees = Array.filter(followRequests, func(request: FollowRequest) : Bool {
            request.follower == msg.caller and request.accepted
        });

        var posts : [Post] = [];
        for (followeeRequest in myFollowees.vals()) {
            let followeePosts = Array.filter(postsArray, func(post: Post) : Bool {
                post.author == followeeRequest.followee
            });
            posts := Array.append(posts, followeePosts);
        };
        return posts;
    };

    //FUncion para ver los que el usuario principal sigue
    public query(msg) func getFollowees() : async [Principal] {
        let followees = Array.filter<FollowRequest>(followRequests, func(request: FollowRequest) : Bool {
            request.follower == msg.caller and request.accepted
        });

        return Array.map<FollowRequest, Principal>(followees, func(request: FollowRequest) : Principal {
            request.followee
        });
    };

    //Funcion para ver los usuarios que me siguen
    public query(msg) func getFollowers() : async [Principal] {
        let followers = Array.filter<FollowRequest>(followRequests, func(request: FollowRequest) : Bool {
            request.followee == msg.caller and request.accepted
        });

        return Array.map<FollowRequest, Principal>(followers, func(request: FollowRequest) : Principal {
            request.follower
        });
    };

    // Función para obtener los comentarios de un post específico
    public query func getComments(postId: Nat) : async [Comment] {
        let maybePost = Array.find(postsArray, func(post: Post) : Bool {
            post.id == postId
        });

        // Usamos un switch para manejar el valor opcional de maybePost
        switch maybePost {
            case (?post) {
                return Array.filter(commentsArray, func(comment: Comment) : Bool {
                    Array.indexOf<Nat>(comment.id, post.comments, func(x, y) { x == y }) != null
                });
            };
            case null {
                return [];  // Si no se encuentra el post, retornamos una lista vacía
            };
        };
    };
}

