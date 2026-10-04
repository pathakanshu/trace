"""A browser-scoped usefulness vote on shared, user-supplied Media.

No identity verification or truth assessment is implied. Existing incident
schemas/reset remain unchanged: the shared library is anchored at root.
"""
node MediaVote {
    has voter_hash: str, active: bool = True, created_at: str = "", updated_at: str = "";
}
