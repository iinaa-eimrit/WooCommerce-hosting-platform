import {Router} from 'express';
import bcrypt from 'bcryptjs';
import {z} from 'zod';
import {pool} from './db.js';
import {admin,type User} from './auth.js';
import {newInviteToken,sha256} from './crypto.js';

const parse=<T>(schema:z.ZodType<T>,value:unknown)=>schema.parse(value);
export const invitesRouter=Router();
invitesRouter.get('/',admin,async(_req,res)=>{
  const {rows}=await pool.query('SELECT id,email,name,expires_at,created_at FROM invitations WHERE accepted_at IS NULL AND expires_at>now() ORDER BY created_at DESC');
  res.json({invites:rows});
});
invitesRouter.post('/',admin,async(req,res)=>{
  const body=parse(z.object({email:z.string().email(),name:z.string().min(1).max(200)}),req.body);
  const email=body.email.toLowerCase();
  const existing=await pool.query('SELECT 1 FROM users WHERE email=$1',[email]);
  if(existing.rowCount)return res.status(409).json({error:'A user with this email already exists'});
  await pool.query('DELETE FROM invitations WHERE email=$1 AND accepted_at IS NULL',[email]);
  const token=newInviteToken();
  const {rows}=await pool.query('INSERT INTO invitations(email,name,token_hash,created_by,expires_at) VALUES($1,$2,$3,$4,now()+interval \'7 days\') RETURNING id,expires_at',[email,body.name,token.hash,(req.user as User).id]);
  res.status(201).json({id:rows[0].id,email,name:body.name,token:token.value,expiresAt:rows[0].expires_at});
});

export const acceptInviteRouter=Router();
acceptInviteRouter.post('/',async(req,res)=>{
  const body=parse(z.object({token:z.string().min(32).max(128),password:z.string().min(10)}),req.body);
  const client=await pool.connect();
  try{
    await client.query('BEGIN');
    const {rows}=await client.query<{id:string;email:string;name:string}>('SELECT id,email,name FROM invitations WHERE token_hash=$1 AND accepted_at IS NULL AND expires_at>now() FOR UPDATE',[sha256(body.token)]);
    const invitation=rows[0];
    if(!invitation){await client.query('ROLLBACK');return res.status(400).json({error:'Invite is invalid, expired, or already used'});}
    const passwordHash=await bcrypt.hash(body.password,10);
    const {rows:users}=await client.query<User>("INSERT INTO users(email,name,role,password_hash) VALUES($1,$2,'member',$3) RETURNING id,email,name,role",[invitation.email,invitation.name,passwordHash]);
    await client.query('UPDATE invitations SET accepted_at=now() WHERE id=$1',[invitation.id]);
    await client.query('COMMIT');
    res.json({ok:true,user:users[0]});
  }catch(error){await client.query('ROLLBACK').catch(()=>undefined);throw error;}
  finally{client.release();}
});
