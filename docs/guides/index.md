---
layout: default
---

<div class="home">

    <section class="intro">
        <div class="grid">
            <div class="unit whole center-on-mobiles">
                <p class="vision">{{ site.vision }}</p>
                <p class="description"> {{ site.description }}</p>
                <p class="details hide-on-mobiles"> {{ site.details }}</p>
            </div>
        </div>
    </section>
   <div class="grid">
        <div class="unit whole">

        <h2>Getting Started</h2>
        <p>{{ site.project }} can be retrieved from Github.</p>

{% highlight bash %}
$ git clone https://github.com/{{ site.repository }}.git
{% endhighlight %}
        <p>See the <a href="/docs/home">Setup guide</a> for full instructions.</p>

        <h2>Quick-start</h2>
        <p>For the impatient, the app is also available in the <a href="#">App Store</a>.</p>

        <h2>Licensing</h2>
        <p>{{ site.title }} is licensed under {{ site.license }}
        <a href="https://github.com/{{ site.repository }}/blob/master/LICENSE">License</a>.</p>

        <h2>Getting Involved</h2>
        <p>Fork the {{ site.project }} repository and do great things. At <a href="{{ site.companyURL }}">
        {{ site.company }}</a>, we want to make {{ site.project }} useful to as many people as possible.</p>

        </div>
    </div>
</div>

