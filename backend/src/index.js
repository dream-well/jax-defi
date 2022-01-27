import express from 'express'
import morgan from 'morgan'
import routes from './routes.js'
import cors from 'cors'
import https from 'https'
import fs from 'fs'

const app = express();

app.use(cors())

app.use(morgan('combined'));


// app.use("/", express.static("frontend", { extensions: ['html'] }));
app.use("/", routes);

app.use(function(err, req, res, next) {
    console.error(err.stack);
    res.status(500).send('Something broke!');
});

app.listen(8080, () => {
    console.log("App is listening port 8080");
    console.log("http://localhost:8080");
})

if(fs.existsSync('/etc/letsencrypt/live/beta.jax.money/fullchain.pem')){
    const crf = fs.readFileSync('/etc/letsencrypt/live/beta.jax.money/fullchain.pem', 'utf-8');
    const privateKey = fs.readFileSync('/etc/letsencrypt/live/beta.jax.money/privkey.pem', 'utf-8');
    const httpsServer = https.createServer({
        key: privateKey,
        cert: crf
    }, app);
    httpsServer.listen(8443);
    console.log("listening on 8443");
}