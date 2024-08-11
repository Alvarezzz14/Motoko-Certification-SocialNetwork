import { HttpAgent, Actor } from "@dfinity/agent";
import { idlFactory as SocialIC_backend_idl } from "socialIc/src/declarations/socialIc_backend";  // Asegúrate de que esta ruta sea correcta

// Declarar la constante para el ID del canister del frontend y Backend
const frontendCanisterId = "be2us-64aaa-aaaaa-qaabq-cai";
const backendCanisterId = "bkyz2-fmaaa-aaaaa-qaaaq-cai";

// Configurar el agente y el actor para interactuar con el canister
async function setupActor() {
    const agent = new HttpAgent.create();
    const SocialIC_backend = Actor.createActor(SocialIC_backend_idl, {
        agent,
        canisterId: backendCanisterId,  // Canister del Backend
    });

    return SocialIC_backend;
}
// Función principal para inicializar la aplicación
setupActor().then(SocialIC_backend => {

    document.getElementById("signup-link").href = `http://127.0.0.1:4943/register.html?canisterId=${frontendCanisterId}`;


    // --- Lógica de Registro ---
    document.getElementById("register-form").addEventListener("submit", async (event) => {
        event.preventDefault();
        const username = document.getElementById("username").value;
        const bio = document.getElementById("bio").value;

        try {
            const response = await SocialIC_backend.createProfile(username, bio);
            if (response) {
                alert("Registration successful! Redirecting to login...");
                window.location.href = "http://127.0.0.1:4943/login.html?canisterId=${frontendCanisterId}";
            } else {
                alert("Registration failed. Please try again.");
            }
        } catch (error) {
            console.error("Error during registration:", error);
        }
    });

    // --- Lógica de Login ---
    document.getElementById("login-form").addEventListener("submit", async (event) => {
        event.preventDefault();

        //Declaramos url de Api Internet Identity para Autenticación
        const iiUrl = `https://identity.ic0.app/#authorize`;
        const redirectUri = encodeURIComponent(`http://127.0.0.1:4943/home.html?canisterId=${frontendCanisterId}`);
        const loginUrl = `${iiUrl}&redirect_uri=${redirectUri}&canisterId=${backendCanisterId}`;

        //Redirigir a II para la auth
        window.location.href = loginUrl;

    });

    // ----- Logica para verificar el perfil en home.html ---

    if (document.getElementById("home-page")) { // Solo se ejecuta en home.html
        document.addEventListener("DOMContentLoaded", async () => {
            try {
                const userProfile = await SocialIC_backend.getMyProfile();

                if (userProfile) {
                    // Si el perfil existe, muestra la página principal o sigue con la lógica de la aplicación
                    console.log("Perfil encontrado:", userProfile);
                    loadPosts(SocialIC_backend);
                } else {
                    // Si no hay perfil, redirige a la página de registro
                    alert("No se encontró un perfil. Por favor, regístrate.");
                    window.location.href = `http://127.0.0.1:4943/register.html?canisterId=${frontendCanisterId}`;
                }
            } catch (error) {
                console.error("Error al verificar el perfil:", error);
            }
        });
    };

    // --- Lógica para Crear y Gestionar Posts ---
    document.getElementById("post-form").addEventListener("submit", async (event) => {
        event.preventDefault();
        const content = document.getElementById("post-content").value;

        try {
            await SocialIC_backend.createPost(content);
            alert("Post created successfully!");
            loadPosts(); // Recargar los posts después de crear uno nuevo
        } catch (error) {
            console.error("Error creating post:", error);
        }
    });

    async function loadPosts() {
        try {
            const posts = await SocialIC_backend.getAllPosts();
            const postsList = document.getElementById("posts-list");
            postsList.innerHTML = ""; // Limpia la lista antes de agregar nuevos posts

            posts.forEach(post => {
                const postElement = document.createElement("div");
                postElement.className = "bg-white p-4 rounded-lg shadow mb-4";
                postElement.innerHTML = `
                    <p class="text-sm text-gray-700">${post.author}</p>
                    <p class="text-lg text-black">${post.content}</p>
                    <small class="text-gray-500">${new Date(post.timestamp).toLocaleString()}</small>
                    <button class="text-red-500" onclick="deletePost('${post.id}')">Delete</button>
                    <button class="text-blue-500" onclick="editPost('${post.id}')">Edit</button>
                    <div id="comments-${post.id}">
                        ${post.comments.map(comment => `
                            <div class="mt-4 bg-gray-100 p-2 rounded">
                                <p class="text-sm text-gray-700">${comment.author}</p>
                                <p>${comment.content}</p>
                                <button class="text-blue-500" onclick="editComment('${post.id}', '${comment.id}')">Edit</button>
                                <button class="text-red-500" onclick="deleteComment('${post.id}', '${comment.id}')">Delete</button>
                            </div>
                        `).join('')}
                        <form onsubmit="addComment(event, '${post.id}')">
                            <input type="text" placeholder="Add a comment..." class="mt-2 p-2 w-full border rounded">
                            <button type="submit" class="mt-2 bg-blue-500 text-white p-2 rounded">Comment</button>
                        </form>
                    </div>
                `;
                postsList.appendChild(postElement);
            });
        } catch (error) {
            console.error("Error loading posts:", error);
        }
    }

    window.deletePost = async function(postId) {
        try {
            await SocialIC_backend.deletePost(postId);
            alert("Post deleted successfully!");
            loadPosts();
        } catch (error) {
            console.error("Error deleting post:", error);
        }
    };

    window.editPost = async function(postId) {
        const newContent = prompt("Enter the new content for the post:");
        if (newContent) {
            try {
                await SocialIC_backend.editPost(postId, newContent);
                alert("Post edited successfully!");
                loadPosts();
            } catch (error) {
                console.error("Error editing post:", error);
            }
        }
    };

    // --- Lógica para Añadir, Editar y Eliminar Comentarios ---
    window.addComment = async function(event, postId) {
        event.preventDefault();
        const commentInput = event.target.querySelector("input[type='text']");
        const content = commentInput.value;

        try {
            await SocialIC_backend.addComment(postId, content);
            alert("Comment added successfully!");
            loadPosts();
        } catch (error) {
            console.error("Error adding comment:", error);
        }
    };

    window.editComment = async function(postId, commentId) {
        const newContent = prompt("Enter the new content for the comment:");
        if (newContent) {
            try {
                await SocialIC_backend.editComment(postId, commentId, newContent);
                alert("Comment edited successfully!");
                loadPosts();
            } catch (error) {
                console.error("Error editing comment:", error);
            }
        }
    };

    window.deleteComment = async function(postId, commentId) {
        try {
            await SocialIC_backend.deleteComment(postId, commentId);
            alert("Comment deleted successfully!");
            loadPosts();
        } catch (error) {
            console.error("Error deleting comment:", error);
        }
    };

    // --- Lógica para Manejar Seguidores ---
    window.toggleFollow = async function(targetPrincipal) {
        try {
            const isFollowing = await SocialIC_backend.isFollowing(targetPrincipal);
            if (isFollowing) {
                await SocialIC_backend.unfollowUser(targetPrincipal);
                alert("You have unfollowed this user.");
            } else {
                await SocialIC_backend.followUser(targetPrincipal);
                alert("You are now following this user.");
            }
            loadFollowers();
        } catch (error) {
            console.error("Error toggling follow status:", error);
        }
    };

    window.acceptFollowRequest = async function(followerPrincipal) {
        try {
            await SocialIC_backend.acceptFollowRequest(followerPrincipal);
            alert("You have accepted the follow request.");
            loadFollowers();
        } catch (error) {
            console.error("Error accepting follow request:", error);
        }
    };

    async function loadFollowers() {
        try {
            const followers = await SocialIC_backend.getFollowers();
            const followees = await SocialIC_backend.getFollowees();
            const followersList = document.getElementById("followers-list");
            const followeesList = document.getElementById("followees-list");

            followersList.innerHTML = "";
            followeesList.innerHTML = "";

            followers.forEach(follower => {
                const followerElement = document.createElement("div");
                followerElement.className = "bg-white p-4 rounded-lg shadow mb-4";
                followerElement.innerHTML = `
                    <p class="text-lg text-black">${follower.username}</p>
                    <button class="text-blue-500" onclick="acceptFollowRequest('${follower.id}')">Accept</button>
                `;
                followersList.appendChild(followerElement);
            });

            followees.forEach(followee => {
                const followeeElement = document.createElement("div");
                followeeElement.className = "bg-white p-4 rounded-lg shadow mb-4";
                followeeElement.innerHTML = `
                    <p class="text-lg text-black">${followee.username}</p>
                    <button class="text-red-500" onclick="toggleFollow('${followee.id}')">Unfollow</button>
                `;
                followeesList.appendChild(followeeElement);
            });
        } catch (error) {
            console.error("Error loading followers and followees:", error);
        }
    }

    async function loadUserProfile(userPrincipal) {
        try {
            const profile = await SocialIC_backend.getProfile(userPrincipal);
            if (profile) {
                document.getElementById("username").innerText = profile.username;
                document.getElementById("bio").innerText = profile.bio;
                document.getElementById("follow-button").onclick = () => toggleFollow(userPrincipal);
            }
        } catch (error) {
            console.error("Error loading user profile:", error);
        }
    }

    if (document.getElementById("profile-page")) {
        const userPrincipal = new URLSearchParams(window.location.search).get("user");
        loadUserProfile(userPrincipal);
    }

    if (document.getElementById("followers-page")) {
        loadFollowers();
    }

    document.getElementById("logout").addEventListener("click", () => {
        alert("Logged out successfully!");
    });

    // Cargar los posts al inicio si estamos en la página de inicio
    if (document.getElementById("posts-list")) {
        loadPosts();
    }
});
